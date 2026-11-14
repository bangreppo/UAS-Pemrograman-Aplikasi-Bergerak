<?php

namespace App\Http\Controllers;

use App\Models\Apartment;
use App\Models\ApartmentMember;
use App\Models\Bill;
use App\Models\Fine;
use App\Models\JoinRequest;
use App\Models\MoveOutRequest;
use App\Models\Occupancy;
use App\Models\Payment;
use App\Models\Report;
use App\Models\Unit;
use App\Models\UnitType;
use App\Models\User;
use App\Models\Announcement;
use App\Services\BillingService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ApartmentController extends Controller
{
    public const MODULES = ['facilities', 'services', 'announcements', 'reports', 'fines', 'move_out'];

    public function index(Request $r)
    {
        return ApartmentMember::with('apartment')->where('user_id', $r->user()->id)->where('is_active', true)->get()
            ->map(fn ($m) => ['role' => $m->role, 'apartment' => $m->apartment]);
    }

    public function store(Request $r)
    {
        $d = $r->validate([
            'name' => 'required|string|max:120',
            'address' => 'required|string|max:255',
            'city' => 'nullable|string|max:80',
            'contact' => 'nullable|string|max:80',
            'description' => 'nullable|string',
            'rules' => 'nullable|string',
            'service_fee' => 'nullable|integer|min:0',
            'electricity_fee' => 'nullable|integer|min:0',
            'water_fee' => 'nullable|integer|min:0',
            'late_fee_per_day' => 'nullable|integer|min:0',
            'late_fee_cap' => 'nullable|integer|min:0',
            'rent_issue_day' => 'nullable|integer|min:1|max:28',
            'due_day' => 'nullable|integer|min:1|max:28',
            'modules' => 'nullable|array',
            'modules.*' => 'string',
            'types' => 'nullable|array',
            'types.*.name' => 'required|string|max:60',
            'types.*.rent_price' => 'required|integer|min:0',
            'types.*.capacity' => 'nullable|integer|min:1|max:6',
            'types.*.count' => 'nullable|integer|min:0|max:500',
            'types.*.area' => 'nullable|numeric',
            'types.*.bedrooms' => 'nullable|integer|min:0|max:10',
            'types.*.bathrooms' => 'nullable|integer|min:0|max:10',
            'types.*.features' => 'nullable|array',
            'floors' => 'nullable|integer|min:1|max:60',
            'prefix' => 'nullable|string|max:10',
        ]);

        return DB::transaction(function () use ($r, $d) {
            $fields = array_filter([
                'name' => $d['name'], 'address' => $d['address'], 'city' => $d['city'] ?? null, 'contact' => $d['contact'] ?? null,
                'description' => $d['description'] ?? null, 'rules' => $d['rules'] ?? null,
                'service_fee' => $d['service_fee'] ?? null, 'electricity_fee' => $d['electricity_fee'] ?? null, 'water_fee' => $d['water_fee'] ?? null,
                'late_fee_per_day' => $d['late_fee_per_day'] ?? null, 'late_fee_cap' => $d['late_fee_cap'] ?? null,
                'rent_issue_day' => $d['rent_issue_day'] ?? null, 'due_day' => $d['due_day'] ?? null,
            ], fn ($v) => $v !== null);
            $a = Apartment::create($fields + [
                'owner_id' => $r->user()->id,
                'modules' => array_values(array_intersect($d['modules'] ?? self::MODULES, self::MODULES)),
            ]);
            ApartmentMember::create(['apartment_id' => $a->id, 'user_id' => $r->user()->id, 'role' => 'owner']);
            $this->createTypesAndUnits($a, $d['types'] ?? [], $d['floors'] ?? 1, $d['prefix'] ?? 'A-');

            return response()->json($a->fresh(), 201);
        });
    }

    protected function createTypesAndUnits(Apartment $a, array $types, int $floors, string $prefix): void
    {
        $created = [];
        foreach ($types as $t) {
            $type = UnitType::create([
                'apartment_id' => $a->id,
                'name' => $t['name'],
                'rent_price' => $t['rent_price'],
                'capacity' => $t['capacity'] ?? 2,
                'area' => $t['area'] ?? null,
                'bedrooms' => $t['bedrooms'] ?? 0,
                'bathrooms' => $t['bathrooms'] ?? 1,
                'features' => $t['features'] ?? [],
            ]);
            $created[] = [$type, (int) ($t['count'] ?? 0)];
        }
        $total = array_sum(array_column($created, 1));
        if ($total < 1) {
            return;
        }
        $per = (int) ceil($total / max(1, $floors));
        $i = 0;
        foreach ($created as [$type, $count]) {
            for ($k = 0; $k < $count; $k++) {
                $floor = intdiv($i, $per) + 1;
                $idx = $i % $per + 1;
                Unit::create([
                    'apartment_id' => $a->id,
                    'unit_type_id' => $type->id,
                    'number' => $prefix.$floor.str_pad((string) $idx, 2, '0', STR_PAD_LEFT),
                    'floor' => $floor,
                    'status' => 'available',
                ]);
                $i++;
            }
        }
    }

    public function show(Request $r, $aid)
    {
        $m = $this->ctx($r, $aid);
        $a = $this->apt($aid);

        return array_merge($a->toArray(), ['my_role' => $m->role]);
    }

    public function update(Request $r, $aid)
    {
        $m = $this->ctx($r, $aid, $this->staff);
        $a = $this->apt($aid);
        $d = $r->validate([
            'name' => 'sometimes|required|string|max:120',
            'address' => 'sometimes|required|string|max:255',
            'city' => 'nullable|string|max:80',
            'contact' => 'nullable|string|max:80',
            'description' => 'nullable|string',
            'rules' => 'nullable|string',
            'late_fee_per_day' => 'sometimes|integer|min:0',
            'late_fee_cap' => 'nullable|integer|min:0',
            'service_fee' => 'sometimes|integer|min:0',
            'electricity_fee' => 'sometimes|integer|min:0',
            'water_fee' => 'sometimes|integer|min:0',
            'rent_issue_day' => 'sometimes|integer|min:1|max:28',
            'due_day' => 'sometimes|integer|min:1|max:28',
            'modules' => 'sometimes|array',
            'modules.*' => 'string',
        ]);
        $allowed = ['name', 'address', 'city', 'contact', 'description', 'rules', 'late_fee_per_day', 'late_fee_cap'];
        if ($m->role === 'owner') {
            $allowed = array_merge($allowed, ['service_fee', 'electricity_fee', 'water_fee', 'rent_issue_day', 'due_day', 'modules']);
        }
        $data = array_intersect_key($d, array_flip($allowed));
        if (isset($data['modules'])) {
            $data['modules'] = array_values(array_intersect($data['modules'], self::MODULES));
        }
        $a->update($data);

        return array_merge($a->fresh()->toArray(), ['my_role' => $m->role]);
    }

    public function dashboard(Request $r, $aid)
    {
        $m = $this->ctx($r, $aid);
        $a = $this->apt($aid);
        $today = now()->startOfDay();

        if ($m->role === 'tenant') {
            return $this->tenantHome($r, $a, $today);
        }

        $period = $r->query('period', 'this_month');
        if ($period === 'last_month') {
            $start = now()->startOfMonth()->subMonthNoOverflow();
            $end = $start->copy()->endOfMonth();
        } elseif ($period === 'year') {
            $start = now()->startOfYear();
            $end = now()->endOfYear();
        } else {
            $period = 'this_month';
            $start = now()->startOfMonth();
            $end = now()->endOfMonth();
        }
        $units = Unit::where('apartment_id', $aid)->selectRaw('status, count(*) as c')->groupBy('status')->pluck('c', 'status');
        $series = [];
        $short = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
        for ($i = 5; $i >= 0; $i--) {
            $s = now()->startOfMonth()->subMonthsNoOverflow($i);
            $series[] = [
                'label' => $short[$s->month - 1],
                'amount' => (int) Payment::where('apartment_id', $aid)->whereBetween('paid_at', [$s, $s->copy()->endOfMonth()])->sum('amount'),
            ];
        }
        $billsInPeriod = Bill::where('apartment_id', $aid)->whereBetween('due_date', [$start->toDateString(), $end->toDateString()])->selectRaw('status, count(*) as c')->groupBy('status')->pluck('c', 'status');
        $reports = Report::where('apartment_id', $aid)->selectRaw('status, count(*) as c')->groupBy('status')->pluck('c', 'status');

        return [
            'role' => $m->role,
            'apartment' => $a,
            'units' => [
                'total' => (int) $units->sum(),
                'available' => (int) ($units['available'] ?? 0),
                'occupied' => (int) ($units['occupied'] ?? 0),
                'maintenance' => (int) ($units['maintenance'] ?? 0),
            ],
            'active_tenants' => Occupancy::where('apartment_id', $aid)->where('status', 'active')->count(),
            'income' => [
                'period' => $period,
                'amount' => (int) Payment::where('apartment_id', $aid)->whereBetween('paid_at', [$start, $end])->sum('amount'),
                'series' => $series,
            ],
            'outstanding' => [
                'bills' => (int) Bill::where('apartment_id', $aid)->where('status', 'unpaid')->sum('total'),
                'fines' => (int) Fine::where('apartment_id', $aid)->whereIn('status', ['running', 'due'])->sum('amount'),
            ],
            'overdue_units' => Bill::where('apartment_id', $aid)->where('status', 'unpaid')->whereDate('due_date', '<', $today->toDateString())->distinct('unit_id')->count('unit_id'),
            'bills_status' => ['paid' => (int) ($billsInPeriod['paid'] ?? 0), 'unpaid' => (int) ($billsInPeriod['unpaid'] ?? 0)],
            'reports' => [
                'menunggu' => (int) ($reports['menunggu'] ?? 0), 'diterima' => (int) ($reports['diterima'] ?? 0),
                'ditangani' => (int) ($reports['ditangani'] ?? 0), 'selesai' => (int) ($reports['selesai'] ?? 0), 'ditolak' => (int) ($reports['ditolak'] ?? 0),
            ],
            'pending_requests' => JoinRequest::where('apartment_id', $aid)->where('status', 'pending')->count(),
            'pending_moveouts' => MoveOutRequest::where('apartment_id', $aid)->where('status', 'pending')->count(),
        ];
    }

    protected function tenantHome(Request $r, Apartment $a, $today): array
    {
        $uid = $r->user()->id;
        $occ = Occupancy::with(['unit.type'])->where('apartment_id', $a->id)->where('user_id', $uid)->where('status', 'active')->first();
        $mates = [];
        $bills = collect();
        $fines = collect();
        if ($occ) {
            $mates = Occupancy::with('user:id,name')->where('unit_id', $occ->unit_id)->where('status', 'active')->get()
                ->map(fn ($o) => ['name' => $o->user->name, 'is_primary' => $o->is_primary, 'is_me' => $o->user_id === $uid])->values();
            $bills = Bill::with('items')->where('unit_id', $occ->unit_id)->where('status', 'unpaid')->orderBy('due_date')->get();
            $fines = Fine::where('unit_id', $occ->unit_id)->whereIn('status', ['running', 'due'])->get();
        }

        return [
            'role' => 'tenant',
            'apartment' => $a,
            'occupancy' => $occ,
            'housemates' => $mates,
            'unpaid_bills' => $bills->map(fn ($b) => array_merge($b->toArray(), ['is_overdue' => $b->due_date->lt($today)]))->values(),
            'fines' => $fines->values(),
            'payable_total' => (int) $bills->filter(fn ($b) => $b->payable_from->lte($today))->sum('total') + (int) $fines->sum('amount'),
            'announcements' => in_array('announcements', $a->modules ?? []) ? Announcement::where('apartment_id', $a->id)->orderByDesc('is_pinned')->orderByDesc('created_at')->limit(3)->get() : [],
            'open_reports' => Report::where('apartment_id', $a->id)->where('user_id', $uid)->whereIn('status', ['menunggu', 'diterima', 'ditangani'])->count(),
        ];
    }

    public function admins(Request $r, $aid)
    {
        $this->ctx($r, $aid, ['owner']);

        return ApartmentMember::with('user:id,name,email,phone')->where('apartment_id', $aid)->whereIn('role', $this->staff)->get();
    }

    public function addAdmin(Request $r, $aid)
    {
        $this->ctx($r, $aid, ['owner']);
        $d = $r->validate(['email' => 'required|email']);
        $u = User::where('email', $d['email'])->first();
        if (! $u) {
            abort(422, 'Akun dengan email tersebut belum terdaftar. Minta yang bersangkutan mendaftar di MyHously terlebih dahulu.');
        }
        $ex = ApartmentMember::where('apartment_id', $aid)->where('user_id', $u->id)->first();
        if ($ex && $ex->role === 'owner') {
            abort(422, 'Akun ini adalah pemilik apartemen.');
        }
        if ($ex && $ex->role === 'tenant' && $ex->is_active) {
            abort(422, 'Akun ini masih tercatat sebagai penghuni apartemen.');
        }
        $m = ApartmentMember::updateOrCreate(['apartment_id' => $aid, 'user_id' => $u->id], ['role' => 'admin', 'is_active' => true]);
        \App\Services\Notify::to([$u->id], (int) $aid, 'Anda ditambahkan sebagai Admin', 'Anda kini dapat mengelola apartemen '.$this->apt($aid)->name.'.', 'info');

        return response()->json($m->load('user:id,name,email,phone'), 201);
    }

    public function removeAdmin(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, ['owner']);
        $m = ApartmentMember::where('apartment_id', $aid)->where('user_id', $id)->where('role', 'admin')->firstOrFail();
        $m->update(['is_active' => false]);

        return ['message' => 'Admin dinonaktifkan.'];
    }

    public function runBilling(Request $r, $aid)
    {
        $this->ctx($r, $aid, $this->staff);
        $a = $this->apt($aid);
        $action = $r->validate(['action' => 'required|in:rent,extras,fines'])['action'];
        $today = now()->startOfDay();
        $svc = new BillingService();
        if ($action === 'rent') {
            $n = $svc->issueRent($a, $today->copy()->addMonthNoOverflow()->startOfMonth(), $today);
            $msg = $n.' tagihan sewa '.BillingService::bulan($today->copy()->addMonthNoOverflow()).' diterbitkan.';
        } elseif ($action === 'extras') {
            $this->module($a, 'services');
            $n = $svc->issueExtras($a, $today->copy()->startOfMonth(), $today, true);
            $msg = $n.' tagihan layanan tambahan '.BillingService::bulan($today).' diterbitkan.';
        } else {
            $this->module($a, 'fines');
            $n = $svc->calcFines($a, $today);
            $msg = 'Penghitungan denda selesai. '.$n.' denda baru dibuat; denda berjalan diperbarui.';
        }

        return ['created' => $n, 'message' => $msg];
    }
}
