<!doctype html>
<html lang="id"><head><meta charset="utf-8">
<style>
body{font-family:'DejaVu Sans',sans-serif;font-size:12px;color:#17211f}
h1{font-size:20px;margin:0 0 2px}h2{font-size:15px;margin:18px 0 8px}
.muted{color:#66726e}table{width:100%;border-collapse:collapse}
th,td{padding:6px 4px;border-bottom:1px solid #e1e6e3;text-align:left;vertical-align:top}
.r{text-align:right}.sub td{font-size:11px;color:#66726e;border-bottom:0;padding:1px 4px 1px 16px}
.total td{font-weight:bold;font-size:14px;border-top:2px solid #17211f;border-bottom:0}
.badge{display:inline-block;padding:3px 10px;border:1px solid #2e7d4f;color:#2e7d4f;border-radius:10px;font-size:11px}
</style></head><body>
<h1>{{ $apt->name }}</h1>
<div class="muted">{{ $apt->address }}@if($apt->contact) &middot; {{ $apt->contact }}@endif</div>
<h2>Bukti Pembayaran <span class="badge">LUNAS (simulasi)</span></h2>
<table>
<tr><td style="width:30%" class="muted">No. kwitansi</td><td>{{ $p->receipt_no }}</td></tr>
<tr><td class="muted">Tanggal</td><td>{{ $p->paid_at->format('d/m/Y H:i') }}</td></tr>
<tr><td class="muted">Unit</td><td>{{ $p->unit?->number ?? '-' }}</td></tr>
<tr><td class="muted">Pembayar</td><td>{{ $p->user?->name }}</td></tr>
<tr><td class="muted">Metode</td><td>{{ $p->method }}</td></tr>
</table>
<h2>Rincian</h2>
<table>
@foreach($items as $it)
<tr><td><strong>{{ $it['label'] }}</strong></td><td class="r"><strong>{{ \App\Services\BillingService::rp($it['amount']) }}</strong></td></tr>
@foreach($it['components'] as $c)
<tr class="sub"><td>{{ $c['label'] }}</td><td class="r">{{ \App\Services\BillingService::rp($c['amount']) }}</td></tr>
@endforeach
@endforeach
<tr class="total"><td>Total dibayar</td><td class="r">{{ \App\Services\BillingService::rp($p->amount) }}</td></tr>
</table>
<p class="muted" style="margin-top:24px;font-size:10px">Dokumen ini dibuat otomatis oleh MyHously. Pembayaran bersifat simulasi pencatatan internal dan bukan transaksi uang sungguhan.</p>
</body></html>
