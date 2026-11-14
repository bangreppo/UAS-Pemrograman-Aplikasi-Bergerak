<?php

namespace App\Services;

use App\Models\Apartment;
use App\Models\ApartmentMember;
use App\Models\Bill;
use App\Models\BillItem;
use App\Models\Fine;
use App\Models\Occupancy;
use App\Models\ServiceSubscription;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class BillingService
{
    public bool $silent = false;

    public static function bulan(Carbon $d): string
    {
        $m = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

        return $m[$d->month - 1].' '.$d->year;
    }

    public static function rp(int|float $n): string
    {
        return 'Rp'.number_format($n, 0, ',', '.');
    }

    public function dueDate(Apartment $a, Carbon $month): Carbon
    {
        $m = $month->copy()->startOfMonth();

        return $m->day(min((int) $a->due_day, $m->daysInMonth));
    }

    public function rentItems(Apartment $a, Occupancy $o): array
    {
        $o->loadMissing('unit.type');
        $items = [['rent', 'Sewa unit '.$o->unit->number.' ('.$o->unit->type->name.')', (int) $o->unit->type->rent_price]];
        if ($a->service_fee > 0) {
            $items[] = ['service_charge', 'Service charge', (int) $a->service_fee];
        }
        if ($a->electricity_fee > 0) {
            $items[] = ['electricity', 'Listrik', (int) $a->electricity_fee];
        }
        if ($a->water_fee > 0) {
            $items[] = ['water', 'Air', (int) $a->water_fee];
        }

        return $items;
    }

    public function make(Apartment $a, Occupancy $o, string $kind, Carbon $period, string $label, Carbon $issued, Carbon $payFrom, Carbon $due, array $items): Bill
    {
        return DB::transaction(function () use ($a, $o, $kind, $period, $label, $issued, $payFrom, $due, $items) {
            $bill = Bill::create([
                'apartment_id' => $a->id,
                'unit_id' => $o->unit_id,
                'occupancy_id' => $o->id,
                'user_id' => $o->user_id,
                'kind' => $kind,
                'label' => $label,
                'period' => $period->toDateString(),
                'issued_on' => $issued->toDateString(),
                'payable_from' => $payFrom->toDateString(),
                'due_date' => $due->toDateString(),
                'total' => array_sum(array_column($items, 2)),
                'status' => 'unpaid',
            ]);
            foreach ($items as $it) {
                BillItem::create(['bill_id' => $bill->id, 'type' => $it[0], 'label' => $it[1], 'amount' => $it[2]]);
            }
            if (! $this->silent) {
                $extra = $payFrom->gt($issued) ? ' Dapat dibayar mulai '.$payFrom->format('d/m/Y').'.' : '';
                Notify::to([$o->user_id], $a->id, 'Tagihan baru', $label.' sebesar '.self::rp($bill->total).', jatuh tempo '.$due->format('d/m/Y').'.'.$extra, 'bill');
            }

            return $bill;
        });
    }

    public function issueRent(Apartment $a, Carbon $forMonth, Carbon $today): int
    {
        $forMonth = $forMonth->copy()->startOfMonth();
        $n = 0;
        $occs = Occupancy::with('unit.type')->where('apartment_id', $a->id)->where('status', 'active')->where('is_primary', true)->get();
        foreach ($occs as $o) {
            if ($o->start_date && $o->start_date->gt($forMonth->copy()->endOfMonth())) {
                continue;
            }
            if ($o->end_date && $o->end_date->lt($forMonth)) {
                continue;
            }
            $exists = Bill::where('occupancy_id', $o->id)->where('kind', 'rent')->whereDate('period', $forMonth->toDateString())->exists();
            if ($exists) {
                continue;
            }
            $this->make($a, $o, 'rent', $forMonth, 'Sewa '.self::bulan($forMonth), $today, $today, $this->dueDate($a, $forMonth), $this->rentItems($a, $o));
            $n++;
        }

        return $n;
    }

    public function issueExtras(Apartment $a, Carbon $forMonth, Carbon $today, bool $immediate = false): int
    {
        if (! in_array('services', $a->modules ?? [])) {
            return 0;
        }
        $forMonth = $forMonth->copy()->startOfMonth();
        $next = $forMonth->copy()->addMonthNoOverflow()->startOfMonth();
        $n = 0;
        $occs = Occupancy::where('apartment_id', $a->id)->where('status', 'active')->where('is_primary', true)->get();
        foreach ($occs as $o) {
            $subs = ServiceSubscription::with('service')->where('occupancy_id', $o->id)->get()->filter(fn ($s) => $s->service && $s->service->is_active);
            if ($subs->isEmpty()) {
                continue;
            }
            $exists = Bill::where('occupancy_id', $o->id)->where('kind', 'extras')->whereDate('period', $forMonth->toDateString())->exists();
            if ($exists) {
                continue;
            }
            $items = $subs->map(fn ($s) => ['service', $s->service->name, (int) $s->service->price])->values()->all();
            $payFrom = $immediate ? $today : $next;
            $this->make($a, $o, 'extras', $forMonth, 'Layanan tambahan '.self::bulan($forMonth), $today, $payFrom, $this->dueDate($a, $next), $items);
            $n++;
        }

        return $n;
    }

    public function calcFines(Apartment $a, Carbon $today): int
    {
        if (! in_array('fines', $a->modules ?? [])) {
            return 0;
        }
        $today = $today->copy()->startOfDay();
        $n = 0;
        $rows = Bill::where('apartment_id', $a->id)->where('status', 'unpaid')
            ->whereDate('due_date', '<', $today->toDateString())
            ->selectRaw('occupancy_id, min(due_date) as first_due')->groupBy('occupancy_id')->get();
        foreach ($rows as $r) {
            $occ = Occupancy::find($r->occupancy_id);
            if (! $occ) {
                continue;
            }
            $first = Carbon::parse($r->first_due)->startOfDay();
            $days = (int) abs($first->diffInDays($today));
            $started = $first->copy()->addDay()->toDateString();
            $waived = Fine::where('occupancy_id', $occ->id)->where('status', 'waived')->whereDate('started_on', $started)->exists();
            if ($waived) {
                continue;
            }
            $amount = $days * (int) $a->late_fee_per_day;
            if ($a->late_fee_cap) {
                $amount = min($amount, (int) $a->late_fee_cap);
            }
            $fine = Fine::where('occupancy_id', $occ->id)->where('status', 'running')->first();
            if (! $fine) {
                Fine::create([
                    'apartment_id' => $a->id, 'unit_id' => $occ->unit_id, 'occupancy_id' => $occ->id, 'user_id' => $occ->user_id,
                    'days' => $days, 'amount' => $amount, 'started_on' => $started, 'status' => 'running',
                ]);
                if (! $this->silent) {
                    $staff = ApartmentMember::where('apartment_id', $a->id)->whereIn('role', ['owner', 'admin'])->where('is_active', true)->pluck('user_id')->all();
                    Notify::to([$occ->user_id], $a->id, 'Denda keterlambatan berjalan', 'Tagihan Anda melewati jatuh tempo. Denda '.self::rp($a->late_fee_per_day).' per hari mulai dihitung.', 'fine');
                    Notify::to($staff, $a->id, 'Penghuni terlambat membayar', 'Unit '.$occ->unit()->value('number').' melewati jatuh tempo.', 'fine');
                }
                $n++;
            } else {
                $fine->days = $days;
                if (! $fine->is_adjusted) {
                    $fine->amount = $amount;
                }
                $fine->save();
            }
        }
        $this->freezeFines($a);

        return $n;
    }

    public function freezeFines(Apartment $a): void
    {
        $today = now()->toDateString();
        foreach (Fine::where('apartment_id', $a->id)->where('status', 'running')->get() as $f) {
            $still = Bill::where('occupancy_id', $f->occupancy_id)->where('status', 'unpaid')->whereDate('due_date', '<', $today)->exists();
            if (! $still) {
                $f->status = 'due';
                $f->save();
            }
        }
    }
}
