<?php

namespace App\Http\Controllers;

use App\Models\Apartment;
use App\Models\Bill;
use App\Models\Fine;
use App\Models\Occupancy;
use App\Models\Payment;
use App\Models\PaymentItem;
use App\Support\Demo;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\URL;

class ExportController extends Controller
{
    protected function range(string $p): array
    {
        $now = Demo::now();
        if ($p === 'last_month') {
            $s = $now->copy()->startOfMonth()->subMonthNoOverflow();

            return [$s, $s->copy()->endOfMonth()];
        }
        if ($p === 'year') {
            return [$now->copy()->startOfYear(), $now->copy()->endOfYear()];
        }
        if ($p === 'all') {
            return [Carbon::create(2000, 1, 1)->startOfDay(), $now->copy()->addYears(5)];
        }

        return [$now->copy()->startOfMonth(), $now->copy()->endOfMonth()];
    }

    protected function label(string $p): string
    {
        return match ($p) {
            'last_month' => 'Bulan lalu',
            'year' => 'Tahun ini',
            'all' => 'Semua periode',
            default => 'Bulan ini',
        };
    }

    public function receiptLink(Request $r, $aid, $id)
    {
        $m = $this->ctx($r, $aid);
        $p = Payment::where('apartment_id', $aid)->findOrFail($id);
        if ($m->role === 'tenant') {
            $mine = $p->user_id === $r->user()->id
                || Occupancy::where('apartment_id', $aid)->where('user_id', $r->user()->id)->where('status', 'active')->where('unit_id', $p->unit_id)->exists();
            if (! $mine) {
                abort(403, 'Anda tidak memiliki akses ke data ini.');
            }
        }
        URL::forceRootUrl($r->root());

        return ['url' => URL::temporarySignedRoute('files.receipt', now()->addMinutes(10), ['aid' => $aid, 'id' => $id])];
    }

    public function exportLink(Request $r, $aid)
    {
        $this->ctx($r, $aid, $this->staff);
        $d = $r->validate(['type' => 'required|in:payments,bills,occupants,finance', 'period' => 'nullable|in:this_month,last_month,year,all']);
        URL::forceRootUrl($r->root());

        return ['url' => URL::temporarySignedRoute('files.export', now()->addMinutes(10), ['aid' => $aid, 'type' => $d['type'], 'period' => $d['period'] ?? 'this_month'])];
    }

    protected function pdf(string $html, string $name)
    {
        $d = new \Dompdf\Dompdf(['defaultFont' => 'DejaVu Sans']);
        $d->loadHtml($html, 'UTF-8');
        $d->setPaper('A4', 'portrait');
        $d->render();

        return response($d->output(), 200, ['Content-Type' => 'application/pdf', 'Content-Disposition' => 'inline; filename="'.$name.'"']);
    }

    protected function csv(string $name, array $header, array $rows)
    {
        return response()->streamDownload(function () use ($header, $rows) {
            $o = fopen('php://output', 'w');
            fwrite($o, "\xEF\xBB\xBF");
            fputcsv($o, $header, ',', '"', '\\');
            foreach ($rows as $row) {
                fputcsv($o, $row, ',', '"', '\\');
            }
            fclose($o);
        }, $name, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    public function receipt($aid, $id)
    {
        $p = Payment::with(['user:id,name,email', 'unit:id,number'])->where('apartment_id', $aid)->findOrFail($id);
        $apt = Apartment::findOrFail($aid);
        $items = PaymentItem::where('payment_id', $p->id)->get()->map(function ($i) {
            if ($i->payable_type === 'bill') {
                $b = Bill::with('items')->find($i->payable_id);

                return [
                    'label' => $b?->label ?? 'Tagihan',
                    'amount' => $i->amount,
                    'components' => $b ? $b->items->map(fn ($x) => ['label' => $x->label, 'amount' => $x->amount])->all() : [],
                ];
            }

            return ['label' => 'Denda keterlambatan', 'amount' => $i->amount, 'components' => []];
        })->all();

        return $this->pdf(view('pdf.receipt', compact('p', 'apt', 'items'))->render(), 'kwitansi-'.$p->receipt_no.'.pdf');
    }

    public function export(Request $request, $aid, $type)
    {
        $apt = Apartment::findOrFail($aid);
        $period = (string) $request->query('period', 'this_month');
        [$from, $to] = $this->range($period);
        $stamp = Demo::now()->format('Ymd');

        if ($type === 'payments') {
            $rows = [];
            foreach (Payment::with(['user:id,name', 'unit:id,number'])->where('apartment_id', $aid)->whereBetween('paid_at', [$from, $to])->orderBy('paid_at')->get() as $p) {
                $labels = PaymentItem::where('payment_id', $p->id)->get()->map(fn ($i) => $i->payable_type === 'bill' ? (Bill::find($i->payable_id)?->label ?? 'Tagihan') : 'Denda keterlambatan')->implode('; ');
                $rows[] = [$p->receipt_no, $p->paid_at->format('Y-m-d H:i'), $p->unit?->number, $p->user?->name, $p->method, $p->amount, $labels];
            }

            return $this->csv("pembayaran-$stamp.csv", ['No. Kwitansi', 'Tanggal', 'Unit', 'Penghuni', 'Metode', 'Jumlah (Rp)', 'Rincian'], $rows);
        }
        if ($type === 'bills') {
            $rows = [];
            foreach (Bill::with(['unit:id,number', 'user:id,name'])->where('apartment_id', $aid)->whereBetween('due_date', [$from->toDateString(), $to->toDateString()])->orderBy('due_date')->get() as $b) {
                $rows[] = [$b->label, ['rent' => 'Sewa', 'extras' => 'Layanan tambahan', 'special' => 'Biaya khusus'][$b->kind] ?? $b->kind, $b->unit?->number, $b->user?->name, $b->issued_on->format('Y-m-d'), $b->due_date->format('Y-m-d'), $b->total, $b->status === 'paid' ? 'Lunas' : 'Belum lunas', $b->paid_at?->format('Y-m-d H:i')];
            }

            return $this->csv("tagihan-$stamp.csv", ['Keterangan', 'Jenis', 'Unit', 'Penghuni', 'Terbit', 'Jatuh Tempo', 'Total (Rp)', 'Status', 'Dibayar'], $rows);
        }
        if ($type === 'occupants') {
            $rows = [];
            foreach (Occupancy::with(['user:id,name,email,phone', 'unit:id,number'])->where('apartment_id', $aid)->orderBy('status')->orderBy('unit_id')->get() as $o) {
                $rows[] = [$o->unit?->number, $o->user?->name, $o->user?->email, $o->user?->phone, $o->is_primary ? 'Utama' : 'Tambahan', $o->start_date?->format('Y-m-d'), $o->end_date?->format('Y-m-d'), $o->deposit, $o->status === 'active' ? 'Aktif' : 'Berakhir'];
            }

            return $this->csv("penghuni-$stamp.csv", ['Unit', 'Nama', 'Email', 'Telepon', 'Peran', 'Mulai', 'Berakhir', 'Deposit (Rp)', 'Status'], $rows);
        }
        abort_unless($type === 'finance', 404);

        $pays = Payment::with(['user:id,name', 'unit:id,number'])->where('apartment_id', $aid)->whereBetween('paid_at', [$from, $to])->orderBy('paid_at')->get();
        $due = Bill::where('apartment_id', $aid)->whereBetween('due_date', [$from->toDateString(), $to->toDateString()]);
        $data = [
            'apt' => $apt, 'label' => $this->label($period), 'from' => $from, 'to' => $to > Demo::now()->addYears(2) ? Demo::now() : $to, 'printed' => Demo::now(),
            'pays' => $pays, 'income' => (int) $pays->sum('amount'),
            'paid' => (clone $due)->where('status', 'paid')->count(), 'unpaid' => (clone $due)->where('status', 'unpaid')->count(),
            'unpaidTotal' => (int) (clone $due)->where('status', 'unpaid')->sum('total'),
            'fines' => (int) Fine::where('apartment_id', $aid)->whereIn('status', ['running', 'due'])->sum('amount'),
            'byMethod' => $pays->groupBy('method')->map(fn ($g) => $g->sum('amount')),
        ];

        return $this->pdf(view('pdf.finance', $data)->render(), "laporan-keuangan-$stamp.pdf");
    }
}
