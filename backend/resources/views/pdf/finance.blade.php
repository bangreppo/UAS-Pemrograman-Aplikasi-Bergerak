<!doctype html>
<html lang="id"><head><meta charset="utf-8">
<style>
body{font-family:'DejaVu Sans',sans-serif;font-size:11px;color:#17211f}
h1{font-size:19px;margin:0 0 2px}h2{font-size:14px;margin:16px 0 6px}
.muted{color:#66726e}table{width:100%;border-collapse:collapse}
th,td{padding:5px 4px;border-bottom:1px solid #e1e6e3;text-align:left}
th{background:#f1f4f2}.r{text-align:right}
</style></head><body>
<h1>Laporan Keuangan &mdash; {{ $apt->name }}</h1>
<div class="muted">Periode: {{ $label }} ({{ $from->format('d/m/Y') }} s.d. {{ $to->format('d/m/Y') }}) &middot; dicetak {{ $printed->format('d/m/Y H:i') }}</div>
<h2>Ringkasan</h2>
<table>
<tr><td style="width:60%">Pendapatan tercatat</td><td class="r"><strong>{{ \App\Services\BillingService::rp($income) }}</strong></td></tr>
<tr><td>Jumlah transaksi</td><td class="r">{{ $pays->count() }}</td></tr>
<tr><td>Tagihan jatuh tempo pada periode: lunas / belum lunas</td><td class="r">{{ $paid }} / {{ $unpaid }}</td></tr>
<tr><td>Tunggakan tagihan belum lunas (periode)</td><td class="r">{{ \App\Services\BillingService::rp($unpaidTotal) }}</td></tr>
<tr><td>Denda berjalan / belum dibayar (saat ini)</td><td class="r">{{ \App\Services\BillingService::rp($fines) }}</td></tr>
</table>
@if($byMethod->count())
<h2>Per metode pembayaran</h2>
<table>
@foreach($byMethod as $m => $sum)
<tr><td>{{ $m }}</td><td class="r">{{ \App\Services\BillingService::rp($sum) }}</td></tr>
@endforeach
</table>
@endif
<h2>Daftar pembayaran</h2>
<table>
<tr><th>Tanggal</th><th>No. kwitansi</th><th>Unit</th><th>Penghuni</th><th>Metode</th><th class="r">Jumlah</th></tr>
@forelse($pays as $p)
<tr><td>{{ $p->paid_at->format('d/m/Y') }}</td><td>{{ $p->receipt_no }}</td><td>{{ $p->unit?->number }}</td><td>{{ $p->user?->name }}</td><td>{{ $p->method }}</td><td class="r">{{ \App\Services\BillingService::rp($p->amount) }}</td></tr>
@empty
<tr><td colspan="6" class="muted">Belum ada pembayaran pada periode ini.</td></tr>
@endforelse
</table>
</body></html>
