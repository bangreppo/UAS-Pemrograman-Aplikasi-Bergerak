<?php

namespace App\Http\Controllers;

use App\Support\Demo;

use App\Models\User;

use App\Models\Apartment;

use App\Models\ApartmentMember;
use App\Models\Bill;
use App\Models\Fine;
use App\Models\Invite;
use App\Models\JoinRequest;
use App\Models\MoveOutRequest;
use App\Models\Occupancy;
use App\Models\ServiceSubscription;
use App\Models\Unit;
use App\Services\Notify;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TenancyController extends Controller
{
    protected function capacityLeft(Unit $u): int
    {
        $u->loadMissing('type');

        return (int) $u->type->capacity - Occupancy::where('unit_id', $u->id)->where('status', 'active')->count();
    }

    public function storeInvite(Request $r, $aid)
    {
        $this->ctx($r, $aid, $this->staff);
        $d = $r->validate([
            'unit_id' => 'required|integer',
            'is_primary' => 'nullable|boolean',
            'start_date' => 'nullable|date',
            'end_date' => 'nullable|date|after_or_equal:start_date',
            'deposit' => 'nullable|integer|min:0',
            'days_valid' => 'nullable|integer|min:1|max:90',
        ]);
        $unit = Unit::with('type')->where('apartment_id', $aid)->findOrFail($d['unit_id']);
        if ($unit->status === 'maintenance') {
            abort(422, 'Unit sedang tidak tersedia.');
        }
        if ($this->capacityLeft($unit) <= 0) {
            abort(422, 'Unit sudah mencapai kapasitas penghuni.');
        }
        $primary = $d['is_primary'] ?? true;
        if ($primary && Occupancy::where('unit_id', $unit->id)->where('status', 'active')->where('is_primary', true)->exists()) {
            $primary = false;
        }
        do {
            $code = 'MYH-'.strtoupper(Str::random(6));
        } while (Invite::where('code', $code)->exists());
        $inv = Invite::create([
            'apartment_id' => $aid, 'unit_id' => $unit->id, 'code' => $code, 'is_primary' => $primary,
            'start_date' => $d['start_date'] ?? Demo::now()->toDateString(), 'end_date' => $d['end_date'] ?? null,
            'deposit' => $d['deposit'] ?? 0, 'expires_at' => Demo::now()->addDays($d['days_valid'] ?? 14), 'created_by' => $r->user()->id,
        ]);

        return response()->json($inv->load('unit:id,number'), 201);
    }

    public function invites(Request $r, $aid)
    {
        $this->ctx($r, $aid, $this->staff);

        return Invite::with('unit:id,number')->where('apartment_id', $aid)->orderByDesc('id')->limit(50)->get();
    }

    public function preview(Request $r)
    {
        $code = strtoupper(trim((string) $r->query('code')));
        $apt = Apartment::where('join_code', $code)->where('allow_unit_requests', true)->first();
        if ($apt) {
            $units = Unit::with('type')->where('apartment_id', $apt->id)->where('status', 'available')->orderBy('floor')->orderBy('number')->get()
                ->map(fn ($u) => ['id' => $u->id, 'number' => $u->number, 'floor' => $u->floor, 'building' => $u->building, 'type' => $u->type])->values();
            if ($units->isEmpty()) {
                abort(422, 'Belum ada unit yang tersedia untuk diajukan di apartemen ini.');
            }

            return ['mode' => 'apartment', 'apartment' => $apt->only(['id', 'name', 'address', 'city']), 'units' => $units];
        }
        $inv = $this->findInvite($code);

        return ['mode' => 'invite'] + $this->invitePayload($inv);
    }

    protected function findInvite(string $code): Invite
    {
        $inv = Invite::where('code', strtoupper(trim($code)))->first();
        if (! $inv) {
            abort(422, 'Kode undangan tidak ditemukan.');
        }
        if ($inv->used_at) {
            abort(422, 'Kode undangan sudah digunakan.');
        }
        if ($inv->expires_at && Demo::now()->gt($inv->expires_at)) {
            abort(422, 'Kode undangan sudah kedaluwarsa. Minta kode baru kepada pengelola.');
        }

        return $inv;
    }

    protected function invitePayload(Invite $inv): array
    {
        $unit = Unit::with('type')->find($inv->unit_id);
        $apt = \App\Models\Apartment::find($inv->apartment_id, ['id', 'name', 'address', 'city']);

        return [
            'apartment' => $apt,
            'unit' => ['id' => $unit->id, 'number' => $unit->number, 'floor' => $unit->floor, 'type' => $unit->type],
            'is_primary' => $inv->is_primary,
            'start_date' => $inv->start_date?->toDateString(),
            'end_date' => $inv->end_date?->toDateString(),
            'deposit' => $inv->deposit,
        ];
    }

    protected function assertCanRequest(int $aptId, Unit $unit, int $uid): void
    {
        if ($unit->status === 'maintenance') {
            abort(422, 'Unit sedang tidak tersedia.');
        }
        if ($this->capacityLeft($unit) <= 0) {
            abort(422, 'Unit sudah mencapai kapasitas penghuni.');
        }
        $m = ApartmentMember::where('apartment_id', $aptId)->where('user_id', $uid)->where('is_active', true)->first();
        if ($m && in_array($m->role, $this->staff)) {
            abort(422, 'Akun pengelola tidak dapat menjadi penghuni apartemen yang sama.');
        }
        if (Occupancy::where('apartment_id', $aptId)->where('user_id', $uid)->where('status', 'active')->exists()) {
            abort(422, 'Anda sudah terdaftar sebagai penghuni di apartemen ini.');
        }
        if (JoinRequest::where('apartment_id', $aptId)->where('user_id', $uid)->where('status', 'pending')->exists()) {
            abort(422, 'Anda masih memiliki permintaan yang menunggu persetujuan di apartemen ini.');
        }
    }

    public function join(Request $r)
    {
        $d = $r->validate(['code' => 'required|string', 'unit_id' => 'nullable|integer']);
        $code = strtoupper(trim($d['code']));
        $uid = $r->user()->id;

        return DB::transaction(function () use ($code, $d, $uid) {
            $apt = Apartment::where('join_code', $code)->where('allow_unit_requests', true)->first();
            if ($apt) {
                if (empty($d['unit_id'])) {
                    abort(422, 'Pilih unit yang ingin diajukan.');
                }
                $unit = Unit::with('type')->where('apartment_id', $apt->id)->findOrFail($d['unit_id']);
                if ($unit->status !== 'available') {
                    abort(422, 'Unit ini tidak lagi tersedia untuk diajukan.');
                }
                $this->assertCanRequest($apt->id, $unit, $uid);
                $req = JoinRequest::create([
                    'apartment_id' => $apt->id, 'unit_id' => $unit->id, 'user_id' => $uid, 'invite_id' => null,
                    'is_primary' => true, 'deposit' => 0, 'status' => 'pending',
                ]);
                Notify::to($this->staffIds($apt->id), $apt->id, 'Permintaan unit baru', 'Ada pengajuan untuk unit '.$unit->number.' lewat kode apartemen.', 'join');

                return response()->json($req->load(['apartment:id,name', 'unit:id,number']), 201);
            }
            $inv = $this->findInvite($code);
            $unit = Unit::with('type')->findOrFail($inv->unit_id);
            $this->assertCanRequest($inv->apartment_id, $unit, $uid);
            $req = JoinRequest::create([
                'apartment_id' => $inv->apartment_id, 'unit_id' => $unit->id, 'user_id' => $uid, 'invite_id' => $inv->id,
                'is_primary' => $inv->is_primary, 'start_date' => $inv->start_date, 'end_date' => $inv->end_date, 'deposit' => $inv->deposit,
                'status' => 'pending',
            ]);
            $inv->update(['used_at' => Demo::now()]);
            Notify::to($this->staffIds($inv->apartment_id), $inv->apartment_id, 'Permintaan bergabung baru', 'Ada permintaan bergabung untuk unit '.$unit->number.'.', 'join');

            return response()->json($req->load(['apartment:id,name', 'unit:id,number']), 201);
        });
    }

    public function cancel(Request $r, $id)
    {
        $req = JoinRequest::where('user_id', $r->user()->id)->findOrFail($id);
        if ($req->status !== 'pending') {
            abort(422, 'Hanya permintaan yang menunggu yang dapat dibatalkan.');
        }
        $req->update(['status' => 'cancelled']);

        return $req;
    }

    public function requests(Request $r, $aid)
    {
        $this->ctx($r, $aid, $this->staff);
        $q = JoinRequest::with(['user:id,name,email,phone', 'unit:id,number,floor'])->where('apartment_id', $aid);
        if ($r->query('status')) {
            $q->where('status', $r->query('status'));
        }

        return $q->orderByRaw("case when status='pending' then 0 else 1 end")->orderByDesc('id')->limit(100)->get();
    }

    public function decide(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $d = $r->validate(['approve' => 'required|boolean', 'reason' => 'nullable|string|max:255', 'start_date' => 'nullable|date', 'end_date' => 'nullable|date', 'deposit' => 'nullable|integer|min:0']);

        return DB::transaction(function () use ($aid, $id, $d) {
            $req = JoinRequest::where('apartment_id', $aid)->lockForUpdate()->findOrFail($id);
            if ($req->status !== 'pending') {
                abort(422, 'Permintaan ini sudah diproses.');
            }
            $unit = Unit::with('type')->findOrFail($req->unit_id);
            if (! $d['approve']) {
                if (empty($d['reason'])) {
                    abort(422, 'Alasan penolakan wajib diisi.');
                }
                $req->update(['status' => 'rejected', 'reject_reason' => $d['reason']]);
                Notify::to([$req->user_id], $aid, 'Permintaan bergabung ditolak', 'Unit '.$unit->number.': '.$d['reason'], 'join');

                return $req;
            }
            if ($unit->status === 'maintenance') {
                abort(422, 'Unit sedang tidak tersedia.');
            }
            if ($this->capacityLeft($unit) <= 0) {
                abort(422, 'Unit sudah mencapai kapasitas penghuni.');
            }
            $hasPrimary = Occupancy::where('unit_id', $unit->id)->where('status', 'active')->where('is_primary', true)->exists();
            Occupancy::create([
                'apartment_id' => $aid, 'unit_id' => $unit->id, 'user_id' => $req->user_id,
                'is_primary' => $req->is_primary && ! $hasPrimary, 'start_date' => $d['start_date'] ?? $req->start_date ?? Demo::now()->toDateString(),
                'end_date' => $d['end_date'] ?? $req->end_date, 'deposit' => $d['deposit'] ?? $req->deposit, 'status' => 'active',
            ]);
            ApartmentMember::updateOrCreate(['apartment_id' => $aid, 'user_id' => $req->user_id], ['role' => 'tenant', 'is_active' => true]);
            $unit->update(['status' => 'occupied']);
            $req->update(['status' => 'approved']);
            Notify::to([$req->user_id], $aid, 'Permintaan bergabung diterima', 'Selamat datang! Anda kini terdaftar di unit '.$unit->number.'.', 'join');

            return $req;
        });
    }

    public function placeTenant(Request $r, $aid)
    {
        $this->ctx($r, $aid, $this->staff);
        $d = $r->validate([
            'email' => 'required|email', 'unit_id' => 'required|integer', 'is_primary' => 'nullable|boolean',
            'start_date' => 'nullable|date', 'end_date' => 'nullable|date|after_or_equal:start_date', 'deposit' => 'nullable|integer|min:0',
        ]);
        $u = User::where('email', $d['email'])->first();
        if (! $u) {
            abort(422, 'Akun dengan email tersebut belum terdaftar. Minta yang bersangkutan mendaftar, atau buat kode undangan.');
        }
        $unit = Unit::with('type')->where('apartment_id', $aid)->findOrFail($d['unit_id']);
        $this->assertCanRequest((int) $aid, $unit, $u->id);
        $o = DB::transaction(function () use ($d, $u, $unit, $aid) {
            $hasPrimary = Occupancy::where('unit_id', $unit->id)->where('status', 'active')->where('is_primary', true)->exists();
            $o = Occupancy::create([
                'apartment_id' => $aid, 'unit_id' => $unit->id, 'user_id' => $u->id,
                'is_primary' => ($d['is_primary'] ?? true) && ! $hasPrimary, 'start_date' => $d['start_date'] ?? Demo::now()->toDateString(),
                'end_date' => $d['end_date'] ?? null, 'deposit' => $d['deposit'] ?? 0, 'status' => 'active',
            ]);
            ApartmentMember::updateOrCreate(['apartment_id' => $aid, 'user_id' => $u->id], ['role' => 'tenant', 'is_active' => true, 'invite_status' => 'accepted']);
            $unit->update(['status' => 'occupied']);
            Notify::to([$u->id], (int) $aid, 'Anda terdaftar sebagai penghuni', 'Pengelola mendaftarkan Anda di unit '.$unit->number.'.', 'join');

            return $o;
        });

        return response()->json($o->load(['user:id,name,email,phone', 'unit:id,number']), 201);
    }

    public function occupancies(Request $r, $aid)
    {
        $this->ctx($r, $aid, $this->staff);
        $q = Occupancy::with(['user:id,name,email,phone', 'unit:id,number,floor,unit_type_id', 'unit.type:id,name'])->where('apartment_id', $aid);
        $q->where('status', $r->query('status', 'active'));

        return $q->orderBy('unit_id')->orderByDesc('is_primary')->get();
    }

    public function updateOccupancy(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $o = Occupancy::where('apartment_id', $aid)->findOrFail($id);
        $d = $r->validate([
            'start_date' => 'nullable|date',
            'end_date' => 'nullable|date|after_or_equal:start_date',
            'deposit' => 'nullable|integer|min:0',
        ]);
        $o->update($d);

        return $o->fresh();
    }

    public function endOccupancy(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $o = Occupancy::where('apartment_id', $aid)->where('status', 'active')->findOrFail($id);
        $force = $r->boolean('force');
        $unpaid = Bill::where('occupancy_id', $o->id)->where('status', 'unpaid')->count() + Fine::where('occupancy_id', $o->id)->whereIn('status', ['running', 'due'])->count();
        if ($unpaid > 0 && ! $force) {
            return response()->json(['message' => 'Penghuni masih memiliki tagihan atau denda yang belum lunas.', 'needs_force' => true], 409);
        }
        DB::transaction(function () use ($o, $aid) {
            $o->update(['status' => 'ended', 'ended_at' => Demo::now(), 'end_date' => $o->end_date && $o->end_date->lte(Demo::now()) ? $o->end_date : Demo::now()->toDateString()]);
            ServiceSubscription::where('occupancy_id', $o->id)->delete();
            $left = Occupancy::where('unit_id', $o->unit_id)->where('status', 'active')->orderBy('id')->get();
            if ($left->isEmpty()) {
                $unit = Unit::find($o->unit_id);
                if ($unit && $unit->status === 'occupied') {
                    $unit->update(['status' => 'available']);
                }
            } elseif ($o->is_primary && ! $left->contains('is_primary', true)) {
                $left->first()->update(['is_primary' => true]);
            }
            if (! Occupancy::where('apartment_id', $aid)->where('user_id', $o->user_id)->where('status', 'active')->exists()) {
                ApartmentMember::where('apartment_id', $aid)->where('user_id', $o->user_id)->where('role', 'tenant')->update(['is_active' => false]);
            }
            Notify::to([$o->user_id], (int) $aid, 'Masa tinggal berakhir', 'Masa tinggal Anda telah diakhiri oleh pengelola. Riwayat pembayaran tetap tersimpan.', 'info');
        });

        return ['message' => 'Masa tinggal penghuni diakhiri.'];
    }

    public function moveOuts(Request $r, $aid)
    {
        $m = $this->ctx($r, $aid);
        $q = MoveOutRequest::with(['user:id,name', 'occupancy:id,unit_id', 'occupancy.unit:id,number'])->where('apartment_id', $aid);
        if ($m->role === 'tenant') {
            $q->where('user_id', $r->user()->id);
        }

        return $q->orderByRaw("case when status='pending' then 0 else 1 end")->orderByDesc('id')->limit(50)->get();
    }

    public function storeMoveOut(Request $r, $aid)
    {
        $this->ctx($r, $aid, ['tenant']);
        $this->module($this->apt($aid), 'move_out');
        $d = $r->validate(['desired_date' => 'required|date|after_or_equal:today', 'reason' => 'nullable|string|max:500']);
        $o = Occupancy::where('apartment_id', $aid)->where('user_id', $r->user()->id)->where('status', 'active')->first();
        if (! $o) {
            abort(422, 'Anda tidak memiliki unit aktif.');
        }
        if (MoveOutRequest::where('occupancy_id', $o->id)->where('status', 'pending')->exists()) {
            abort(422, 'Permintaan keluar Anda masih menunggu keputusan.');
        }
        $req = MoveOutRequest::create($d + ['apartment_id' => $aid, 'occupancy_id' => $o->id, 'user_id' => $r->user()->id]);
        Notify::to($this->staffIds($aid), (int) $aid, 'Permintaan keluar', 'Penghuni unit '.$o->unit()->value('number').' mengajukan keluar pada '.$d['desired_date'].'.', 'moveout');

        return response()->json($req, 201);
    }

    public function decideMoveOut(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $d = $r->validate(['approve' => 'required|boolean', 'note' => 'nullable|string|max:255']);
        $req = MoveOutRequest::where('apartment_id', $aid)->findOrFail($id);
        if ($req->status !== 'pending') {
            abort(422, 'Permintaan ini sudah diproses.');
        }
        if (! $d['approve'] && empty($d['note'])) {
            abort(422, 'Alasan penolakan wajib diisi.');
        }
        DB::transaction(function () use ($req, $d) {
            $req->update(['status' => $d['approve'] ? 'approved' : 'rejected', 'note' => $d['note'] ?? null]);
            if ($d['approve']) {
                Occupancy::where('id', $req->occupancy_id)->update(['end_date' => $req->desired_date]);
            }
            Notify::to([$req->user_id], (int) $req->apartment_id, $d['approve'] ? 'Permintaan keluar disetujui' : 'Permintaan keluar ditolak',
                $d['approve'] ? 'Tanggal keluar: '.$req->desired_date->format('d/m/Y').'. Pengelola akan mengakhiri masa tinggal Anda pada tanggal tersebut.' : ($d['note'] ?? ''), 'moveout');
        });

        return $req->fresh();
    }
}
