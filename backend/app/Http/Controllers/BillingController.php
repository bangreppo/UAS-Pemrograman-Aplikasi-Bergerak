<?php

namespace App\Http\Controllers;

use App\Support\Demo;

use App\Models\Bill;
use App\Models\Fine;
use App\Models\Occupancy;
use App\Models\Payment;
use App\Models\PaymentItem;
use App\Models\Service;
use App\Models\ServiceSubscription;
use App\Services\BillingService;
use App\Services\Notify;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class BillingController extends Controller
{
    public function services(Request $r, $aid)
    {
        $this->ctx($r, $aid, $this->staff);
        $this->module($this->apt($aid), 'services');

        return Service::with(['subscriptions.occupancy:id,unit_id,user_id', 'subscriptions.occupancy.unit:id,number', 'subscriptions.occupancy.user:id,name'])
            ->where('apartment_id', $aid)->orderBy('name')->get();
    }

    protected function serviceRules(): array
    {
        return ['name' => 'required|string|max:80', 'price' => 'required|integer|min:0', 'description' => 'nullable|string', 'is_active' => 'nullable|boolean'];
    }

    public function storeService(Request $r, $aid)
    {
        $this->ctx($r, $aid, $this->staff);
        $this->module($this->apt($aid), 'services');
        $d = $r->validate($this->serviceRules());

        return response()->json(Service::create($d + ['apartment_id' => $aid]), 201);
    }

    public function updateService(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $s = Service::where('apartment_id', $aid)->findOrFail($id);
        $s->update($r->validate($this->serviceRules()));

        return $s->fresh();
    }

    public function destroyService(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $s = Service::where('apartment_id', $aid)->findOrFail($id);
        $s->delete();

        return ['message' => 'Layanan dihapus.'];
    }

    public function subscribe(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $s = Service::where('apartment_id', $aid)->findOrFail($id);
        $oid = $r->validate(['occupancy_id' => 'required|integer'])['occupancy_id'];
        $o = Occupancy::where('apartment_id', $aid)->where('status', 'active')->findOrFail($oid);
        if (! $o->is_primary) {
            abort(422, 'Layanan ditagihkan ke penghuni utama unit. Pilih penghuni utama.');
        }
        ServiceSubscription::firstOrCreate(['service_id' => $s->id, 'occupancy_id' => $o->id]);

        return ['message' => 'Penghuni didaftarkan ke layanan.'];
    }

    public function unsubscribe(Request $r, $aid, $id, $oid)
    {
        $this->ctx($r, $aid, $this->staff);
        $s = Service::where('apartment_id', $aid)->findOrFail($id);
        ServiceSubscription::where('service_id', $s->id)->where('occupancy_id', $oid)->delete();

        return ['message' => 'Pendaftaran layanan dihentikan.'];
    }

    protected function decorate(Bill $b, Carbon $today): array
    {
        $arr = $b->toArray();
        $over = $b->status === 'unpaid' && $b->due_date->lt($today);
        $arr['is_overdue'] = $over;
        $arr['days_late'] = $over ? (int) abs($b->due_date->copy()->startOfDay()->diffInDays($today)) : 0;
        $arr['payable'] = $b->status === 'unpaid' && $b->payable_from->lte($today);

        return $arr;
    }

    protected function tenantUnitIds(Request $r, $aid)
    {
        return Occupancy::where('apartment_id', $aid)->where('user_id', $r->user()->id)->where('status', 'active')->pluck('unit_id');
    }

    public function bills(Request $r, $aid)
    {
        $m = $this->ctx($r, $aid);
        $today = Demo::now()->startOfDay();
        $q = Bill::with(['items', 'unit:id,number', 'user:id,name'])->where('apartment_id', $aid);
        if ($m->role === 'tenant') {
            $q->whereIn('unit_id', $this->tenantUnitIds($r, $aid));
        }
        if ($r->query('status')) {
            $q->where('status', $r->query('status'));
        }
        if ($r->query('overdue')) {
            $q->where('status', 'unpaid')->whereDate('due_date', '<', $today->toDateString());
        }
        if ($r->query('kind')) {
            $q->where('kind', $r->query('kind'));
        }
        if ($r->query('unit_id') && $m->role !== 'tenant') {
            $q->where('unit_id', $r->query('unit_id'));
        }
        $q->orderByRaw("case when status='unpaid' then 0 else 1 end")->orderByDesc('due_date')->orderByDesc('id');

        return $q->limit(300)->get()->map(fn ($b) => $this->decorate($b, $today))->values();
    }

    public function storeBill(Request $r, $aid)
    {
        $this->ctx($r, $aid, $this->staff);
        $a = $this->apt($aid);
        $d = $r->validate([
            'occupancy_id' => 'required|integer',
            'label' => 'required|string|max:120',
            'amount' => 'required|integer|min:1',
            'due_date' => 'nullable|date|after_or_equal:today',
        ]);
        $o = Occupancy::with('unit.type')->where('apartment_id', $aid)->where('status', 'active')->where('is_primary', true)->findOrFail($d['occupancy_id']);
        $today = Demo::now()->startOfDay();
        $due = isset($d['due_date']) ? Carbon::parse($d['due_date']) : $today->copy()->addDays(7);
        $bill = (new BillingService())->make($a, $o, 'special', $today->copy()->startOfMonth(), $d['label'], $today, $today, $due, [['special', $d['label'], $d['amount']]]);

        return response()->json($bill->load('items'), 201);
    }

    public function fines(Request $r, $aid)
    {
        $m = $this->ctx($r, $aid);
        $q = Fine::with(['unit:id,number', 'user:id,name'])->where('apartment_id', $aid);
        if ($m->role === 'tenant') {
            $q->whereIn('unit_id', $this->tenantUnitIds($r, $aid));
        }
        $status = $r->query('status');
        if ($status === 'open') {
            $q->whereIn('status', ['running', 'due']);
        } elseif ($status) {
            $q->where('status', $status);
        }

        return $q->orderByDesc('id')->limit(200)->get();
    }

    public function adjustFine(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $f = Fine::where('apartment_id', $aid)->findOrFail($id);
        if (! in_array($f->status, ['running', 'due'])) {
            abort(422, 'Denda ini sudah selesai diproses.');
        }
        $d = $r->validate(['action' => 'required|in:waive,set', 'amount' => 'nullable|integer|min:0', 'reason' => 'nullable|string|max:255']);
        if ($d['action'] === 'waive') {
            if (empty($d['reason'])) {
                abort(422, 'Alasan pembebasan denda wajib diisi.');
            }
            $f->update(['status' => 'waived', 'waive_reason' => $d['reason'], 'amount' => 0]);
            Notify::to([$f->user_id], (int) $aid, 'Denda dibebaskan', $d['reason'], 'fine');
        } else {
            if (! isset($d['amount'])) {
                abort(422, 'Nominal denda wajib diisi.');
            }
            $f->update(['amount' => $d['amount'], 'is_adjusted' => true, 'waive_reason' => $d['reason'] ?? null]);
            Notify::to([$f->user_id], (int) $aid, 'Denda disesuaikan', 'Total denda Anda disesuaikan menjadi '.BillingService::rp($d['amount']).'.', 'fine');
        }

        return $f->fresh();
    }

    public function payments(Request $r, $aid)
    {
        $m = $this->ctx($r, $aid);
        $q = Payment::with(['user:id,name', 'unit:id,number'])->withCount('items')->where('apartment_id', $aid);
        if ($m->role === 'tenant') {
            $q->whereIn('unit_id', $this->tenantUnitIds($r, $aid));
        }

        return $q->orderByDesc('paid_at')->orderByDesc('id')->limit(200)->get();
    }

    public function payment(Request $r, $aid, $id)
    {
        $m = $this->ctx($r, $aid);
        $p = Payment::with(['user:id,name', 'unit:id,number'])->where('apartment_id', $aid)->findOrFail($id);
        if ($m->role === 'tenant' && ! $this->tenantUnitIds($r, $aid)->contains($p->unit_id) && $p->user_id !== $r->user()->id) {
            abort(403, 'Anda tidak memiliki akses ke data ini.');
        }
        $items = PaymentItem::where('payment_id', $p->id)->get()->map(function ($i) {
            if ($i->payable_type === 'bill') {
                $b = Bill::with('items')->find($i->payable_id);

                return ['type' => 'bill', 'label' => $b?->label ?? 'Tagihan', 'amount' => $i->amount, 'components' => $b ? $b->items->map(fn ($x) => ['label' => $x->label, 'amount' => $x->amount])->values() : []];
            }

            return ['type' => 'fine', 'label' => 'Denda keterlambatan', 'amount' => $i->amount, 'components' => []];
        });

        return array_merge($p->toArray(), ['items' => $items]);
    }

    public function pay(Request $r, $aid)
    {
        $this->ctx($r, $aid, ['tenant']);
        $a = $this->apt($aid);
        $d = $r->validate([
            'method' => 'required|in:Transfer Bank,QRIS,Virtual Account,E-Wallet',
            'items' => 'required|array|min:1',
            'items.*.type' => 'required|in:bill,fine',
            'items.*.id' => 'required|integer',
        ]);
        $uid = $r->user()->id;
        $today = Demo::now()->startOfDay();

        $payment = DB::transaction(function () use ($d, $a, $uid, $today) {
            $total = 0;
            $lines = [];
            $unitId = null;
            $billIds = [];
            foreach ($d['items'] as $it) {
                if ($it['type'] === 'bill') {
                    $b = Bill::lockForUpdate()->where('apartment_id', $a->id)->find($it['id']);
                    if (! $b || $b->user_id !== $uid) {
                        abort(403, 'Tagihan ini bukan milik Anda. Tagihan unit dibayar oleh penghuni utama.');
                    }
                    if ($b->status !== 'unpaid') {
                        abort(422, 'Tagihan "'.$b->label.'" sudah lunas.');
                    }
                    if ($b->payable_from->gt($today)) {
                        abort(422, 'Tagihan "'.$b->label.'" baru dapat dibayar mulai '.$b->payable_from->format('d/m/Y').'.');
                    }
                    $lines[] = ['bill', $b->id, (int) $b->total];
                    $total += (int) $b->total;
                    $unitId = $b->unit_id;
                    $billIds[] = $b->id;
                } else {
                    $f = Fine::lockForUpdate()->where('apartment_id', $a->id)->find($it['id']);
                    if (! $f || $f->user_id !== $uid) {
                        abort(403, 'Denda ini bukan milik Anda.');
                    }
                    if (! in_array($f->status, ['running', 'due'])) {
                        abort(422, 'Denda ini sudah selesai diproses.');
                    }
                    $lines[] = ['fine', $f->id, (int) $f->amount];
                    $total += (int) $f->amount;
                    $unitId = $unitId ?? $f->unit_id;
                }
            }
            foreach ($lines as [$type, $id]) {
                if ($type === 'fine') {
                    $f = Fine::find($id);
                    $remaining = Bill::where('occupancy_id', $f->occupancy_id)->where('status', 'unpaid')->whereDate('due_date', '<', $today->toDateString())->whereNotIn('id', $billIds)->exists();
                    if ($f->status === 'running' && $remaining) {
                        abort(422, 'Lunasi seluruh tagihan yang sudah jatuh tempo bersama denda ini.');
                    }
                }
            }
            if ($total <= 0) {
                abort(422, 'Tidak ada nominal yang perlu dibayar.');
            }
            $p = Payment::create(['apartment_id' => $a->id, 'user_id' => $uid, 'unit_id' => $unitId, 'method' => $d['method'], 'amount' => $total, 'paid_at' => Demo::now()]);
            $p->update(['receipt_no' => 'MYH-'.Demo::now()->format('Ymd').'-'.str_pad((string) $p->id, 4, '0', STR_PAD_LEFT)]);
            foreach ($lines as [$type, $id, $amount]) {
                PaymentItem::create(['payment_id' => $p->id, 'payable_type' => $type, 'payable_id' => $id, 'amount' => $amount]);
                if ($type === 'bill') {
                    Bill::where('id', $id)->update(['status' => 'paid', 'paid_at' => Demo::now()]);
                } else {
                    Fine::where('id', $id)->update(['status' => 'paid', 'paid_at' => Demo::now()]);
                }
            }
            (new BillingService())->freezeFines($a);

            return $p;
        });

        Notify::to([$uid], (int) $aid, 'Pembayaran berhasil dicatat', 'Pembayaran '.BillingService::rp($payment->amount).' ('.$payment->receipt_no.') telah dicatat.', 'payment');
        Notify::to($this->staffIds($aid), (int) $aid, 'Pembayaran diterima', 'Unit '.$payment->unit()->value('number').' membayar '.BillingService::rp($payment->amount).'.', 'payment');

        return response()->json($payment->load(['user:id,name', 'unit:id,number']), 201);
    }
}
