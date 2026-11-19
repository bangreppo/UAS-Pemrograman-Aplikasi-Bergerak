<?php
/**
 * Uji asap (smoke test) REST API MyHously terhadap server yang sedang berjalan.
 * Pemakaian: php tests/smoke.php http://127.0.0.1:8099/api
 * Data yang diubah uji ini dipulihkan dengan `php artisan migrate:fresh --seed` (dilakukan verify.sh).
 */
$base = rtrim($argv[1] ?? 'http://127.0.0.1:8000/api', '/');
$pass = 0;
$fail = 0;
$fails = [];

function http(string $method, string $url, ?array $json = null, ?string $token = null, ?array $multipart = null): array
{
    $headers = ['Accept: application/json'];
    if ($token) {
        $headers[] = "Authorization: Bearer $token";
    }
    $content = '';
    if ($multipart !== null) {
        $b = '----MYH'.bin2hex(random_bytes(6));
        foreach ($multipart['fields'] ?? [] as $k => $v) {
            $content .= "--$b\r\nContent-Disposition: form-data; name=\"$k\"\r\n\r\n$v\r\n";
        }
        foreach ($multipart['files'] ?? [] as $f) {
            $content .= "--$b\r\nContent-Disposition: form-data; name=\"{$f[0]}\"; filename=\"{$f[2]}\"\r\nContent-Type: {$f[3]}\r\n\r\n{$f[1]}\r\n";
        }
        $content .= "--$b--\r\n";
        $headers[] = "Content-Type: multipart/form-data; boundary=$b";
    } elseif ($json !== null) {
        $headers[] = 'Content-Type: application/json';
        $content = json_encode($json);
    }
    $ctx = stream_context_create(['http' => ['method' => $method, 'header' => implode("\r\n", $headers), 'content' => $content, 'ignore_errors' => true, 'timeout' => 60]]);
    $body = @file_get_contents($url, false, $ctx);
    $code = 0;
    $type = '';
    foreach ($http_response_header ?? [] as $h) {
        if (preg_match('#^HTTP/\S+ (\d+)#', $h, $m)) {
            $code = (int) $m[1];
        }
        if (stripos($h, 'Content-Type:') === 0) {
            $type = trim(substr($h, 13));
        }
    }
    $body = $body === false ? '' : $body;

    return ['code' => $code, 'body' => $body, 'json' => json_decode($body, true), 'type' => $type];
}

function check(string $name, bool $ok, string $detail = ''): void
{
    global $pass, $fail, $fails;
    if ($ok) {
        $pass++;
        echo "  [OK]    $name\n";
    } else {
        $fail++;
        $fails[] = $name.($detail ? " — $detail" : '');
        echo "  [GAGAL] $name".($detail ? "  ($detail)" : '')."\n";
    }
}

function api(string $m, string $path, ?array $body = null, ?string $tok = null, ?array $mp = null): array
{
    global $base;

    return http($m, $base.$path, $body, $tok, $mp);
}

function login(string $email): ?string
{
    $r = api('POST', '/login', ['email' => $email, 'password' => 'password']);

    return $r['json']['token'] ?? null;
}

function aptId(string $tok, string $name): ?int
{
    $r = api('GET', '/me', null, $tok);
    foreach ($r['json']['memberships'] ?? [] as $m) {
        if (($m['apartment']['name'] ?? '') === $name) {
            return (int) $m['apartment_id'];
        }
    }

    return null;
}

$png = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
$suffix = substr(bin2hex(random_bytes(3)), 0, 6);

echo "\n== Autentikasi ==\n";
$r = api('GET', '/demo');
check('Endpoint terlindungi menolak tanpa token (401)', $r['code'] === 401, 'kode '.$r['code']);
$r = api('POST', '/login', ['email' => 'owner@myhously.test', 'password' => 'salah']);
check('Login dengan kata sandi salah ditolak (422)', $r['code'] === 422, 'kode '.$r['code']);
$tOwner = login('owner@myhously.test');
$tAdmin = login('admin1@myhously.test');
$tP1 = login('penghuni1@myhously.test');
$tP4 = login('penghuni4@myhously.test');
$tP6 = login('penghuni6@myhously.test');
$tP11 = login('penghuni11@myhously.test');
$tOwner2 = login('owner2@myhously.test');
$tNewOwner = login('ownerbaru@myhously.test');
check('Login semua akun demo berhasil', $tOwner && $tAdmin && $tP1 && $tP4 && $tP6 && $tP11 && $tOwner2 && $tNewOwner);
if (! $tOwner || ! $tAdmin || ! $tP1) {
    echo "\nLogin gagal, uji dihentikan. Pastikan seeder berhasil.\n";
    exit(1);
}
$A = aptId($tOwner, 'Green Residence Apartment');
$B = aptId($tOwner2, 'Sakura Heights');
check('Apartemen demo ditemukan', $A !== null && $B !== null);
$r = api('GET', '/me', null, $tNewOwner);
check('Owner baru belum memiliki apartemen (tampilan kosong)', count($r['json']['memberships'] ?? [1]) === 0);

echo "\n== Dashboard Owner/Admin ==\n";
$r = api('GET', "/apartments/$A/dashboard", null, $tOwner);
$d = $r['json'] ?? [];
check('Dashboard Owner 200', $r['code'] === 200, 'kode '.$r['code']);
check('Total unit 16 (10 terisi, 4 tersedia, 2 tidak tersedia)', ($d['units']['total'] ?? 0) === 16 && ($d['units']['occupied'] ?? 0) === 10 && ($d['units']['available'] ?? 0) === 4 && ($d['units']['maintenance'] ?? 0) === 2, json_encode($d['units'] ?? null));
check('12 penghuni aktif', ($d['active_tenants'] ?? 0) === 12, (string) ($d['active_tenants'] ?? 'null'));
check('2 unit terlambat', ($d['overdue_units'] ?? -1) === 2, (string) ($d['overdue_units'] ?? 'null'));
check('Denda berjalan Rp600.000 (150.000 + 450.000)', ($d['outstanding']['fines'] ?? 0) === 600000, (string) ($d['outstanding']['fines'] ?? 'null'));
check('Grafik pendapatan 6 bulan', count($d['income']['series'] ?? []) === 6);
$r = api('GET', "/apartments/$A/dashboard", null, $tAdmin);
check('Dashboard Admin 200', $r['code'] === 200);

echo "\n== Isolasi data & hak akses ==\n";
check('Owner apartemen lain ditolak membaca unit (403)', api('GET', "/apartments/$A/units", null, $tOwner2)['code'] === 403);
check('Owner Green ditolak membaca Sakura (403)', api('GET', "/apartments/$B/units", null, $tOwner)['code'] === 403);
check('Penghuni ditolak membaca daftar penghuni (403)', api('GET', "/apartments/$A/occupancies", null, $tP1)['code'] === 403);
check('Penghuni ditolak membuat pengumuman (403)', api('POST', "/apartments/$A/announcements", ['title' => 'x', 'body' => 'y', 'category' => 'info'], $tP1)['code'] === 403);
check('Penghuni ditolak mengubah pengaturan (403)', api('PUT', "/apartments/$A", ['name' => 'Hack'], $tP1)['code'] === 403);
check('Admin ditolak menambah admin (hanya Owner) (403)', api('POST', "/apartments/$A/admins", ['email' => 'ownerbaru@myhously.test'], $tAdmin)['code'] === 403);
$r = api('GET', "/apartments/$A/bills", null, $tP1);
$onlyMine = true;
foreach ($r['json'] ?? [] as $b) {
    if (($b['unit']['number'] ?? '') !== 'A-101') {
        $onlyMine = false;
    }
}
check('Penghuni hanya melihat tagihan unitnya', $r['code'] === 200 && $onlyMine && count($r['json'] ?? []) > 0);
$r = api('GET', "/apartments/$A/fines", null, $tP4);
check('Penghuni A-104 melihat denda Rp150.000', $r['code'] === 200 && count($r['json'] ?? []) >= 1 && (($r['json'][0]['amount'] ?? 0) === 150000), json_encode($r['json'] ?? null));
$r = api('GET', "/apartments/$A/fines", null, $tP11);
check('Penghuni A-303 melihat denda Rp450.000', ($r['json'][0]['amount'] ?? 0) === 450000);
check('Penghuni tanpa denda tidak melihat denda orang lain', count(api('GET', "/apartments/$A/fines", null, $tP1)['json'] ?? [1]) === 0);
check('Sakura: layanan tambahan nonaktif (403)', api('GET', "/apartments/$B/services", null, $tOwner2)['code'] === 403);

echo "\n== Dashboard penghuni ==\n";
$r = api('GET', "/apartments/$A/dashboard", null, $tP1);
check('Beranda penghuni memuat unit A-101', ($r['json']['occupancy']['unit']['number'] ?? '') === 'A-101');
check('Penghuni A-101 tidak punya tunggakan', ($r['json']['payable_total'] ?? -1) === 0, (string) ($r['json']['payable_total'] ?? 'null'));
$r = api('GET', "/apartments/$A/dashboard", null, $tP4);
check('Penghuni A-104 punya tunggakan + denda', ($r['json']['payable_total'] ?? 0) > 150000, (string) ($r['json']['payable_total'] ?? 'null'));

echo "\n== Pembayaran ==\n";
$r = api('GET', "/apartments/$A/bills?status=unpaid", null, $tP6);
$bill = null;
foreach ($r['json'] ?? [] as $b) {
    if (($b['payable'] ?? false) && ($b['kind'] ?? '') === 'rent') {
        $bill = $b;
        break;
    }
}
check('Penghuni A-202 punya tagihan sewa yang dapat dibayar', $bill !== null);
if ($bill) {
    $r = api('POST', "/apartments/$A/payments", ['method' => 'QRIS', 'items' => [['type' => 'bill', 'id' => $bill['id']]]], $tP6);
    check('Pembayaran tagihan sewa berhasil (201)', $r['code'] === 201, 'kode '.$r['code'].' '.substr($r['body'], 0, 120));
    $pid = $r['json']['id'] ?? null;
    check('Nomor kwitansi berformat MYH-', str_starts_with((string) ($r['json']['receipt_no'] ?? ''), 'MYH-'));
    $r2 = api('POST', "/apartments/$A/payments", ['method' => 'QRIS', 'items' => [['type' => 'bill', 'id' => $bill['id']]]], $tP6);
    check('Membayar tagihan yang sudah lunas ditolak (422)', $r2['code'] === 422);
    $r = api('GET', "/apartments/$A/payments/$pid", null, $tP6);
    check('Detail pembayaran memuat rincian', $r['code'] === 200 && count($r['json']['items'] ?? []) === 1);
    check('Penghuni lain ditolak membaca kwitansi (403)', api('GET', "/apartments/$A/payments/$pid", null, $tP11)['code'] === 403);
    $r = api('GET', "/apartments/$A/payments/$pid/pdf-link", null, $tP6);
    $url = $r['json']['url'] ?? null;
    check('Tautan PDF kwitansi dibuat', $url !== null);
    if ($url) {
        $f = http('GET', $url);
        check('Unduh kwitansi PDF (berkas %PDF)', $f['code'] === 200 && str_starts_with($f['body'], '%PDF'), 'kode '.$f['code'].' '.substr($f['body'], 0, 80));
        $tampered = http('GET', $url.'x');
        check('Tautan yang diubah ditolak (403)', $tampered['code'] === 403);
    }
}
$r = api('GET', "/apartments/$A/bills?status=unpaid", null, $tP4);
$bills4 = $r['json'] ?? [];
$fine4 = api('GET', "/apartments/$A/fines?status=open", null, $tP4)['json'][0] ?? null;
$overdue = null;
foreach ($bills4 as $b) {
    if ($b['is_overdue'] ?? false) {
        $overdue = $b;
    }
}
check('Penghuni A-104 punya tagihan terlambat & denda', $overdue !== null && $fine4 !== null);
if ($overdue && $fine4) {
    $r = api('POST', "/apartments/$A/payments", ['method' => 'Transfer Bank', 'items' => [['type' => 'fine', 'id' => $fine4['id']]]], $tP4);
    check('Denda berjalan tidak bisa dibayar tanpa melunasi tagihan jatuh tempo (422)', $r['code'] === 422, 'kode '.$r['code']);
    $r = api('POST', "/apartments/$A/payments", ['method' => 'Transfer Bank', 'items' => [['type' => 'bill', 'id' => $overdue['id']], ['type' => 'fine', 'id' => $fine4['id']]]], $tP4);
    check('Tagihan terlambat + denda dibayar bersamaan (201)', $r['code'] === 201, 'kode '.$r['code'].' '.substr($r['body'], 0, 120));
    $r = api('GET', "/apartments/$A/dashboard", null, $tP4);
    check('Tunggakan penghuni A-104 menjadi 0', ($r['json']['payable_total'] ?? -1) === 0, (string) ($r['json']['payable_total'] ?? 'null'));
}
$r = api('POST', "/apartments/$A/payments", ['method' => 'Cek', 'items' => [['type' => 'bill', 'id' => 1]]], $tP1);
check('Metode pembayaran tidak valid ditolak (422)', $r['code'] === 422);

echo "\n== Denda & penagihan (Admin) ==\n";
$fines = api('GET', "/apartments/$A/fines?status=open", null, $tAdmin)['json'] ?? [];
$f11 = null;
foreach ($fines as $f) {
    if (($f['amount'] ?? 0) === 450000) {
        $f11 = $f;
    }
}
check('Admin melihat denda berjalan penghuni A-303', $f11 !== null);
if ($f11) {
    $r = api('POST', "/apartments/$A/fines/{$f11['id']}/adjust", ['action' => 'waive'], $tAdmin);
    check('Pembebasan denda tanpa alasan ditolak (422)', $r['code'] === 422);
    $r = api('POST', "/apartments/$A/fines/{$f11['id']}/adjust", ['action' => 'set', 'amount' => 200000, 'reason' => 'Keringanan'], $tAdmin);
    check('Admin mengubah nominal denda', $r['code'] === 200 && ($r['json']['amount'] ?? 0) === 200000);
    $r = api('POST', "/apartments/$A/fines/{$f11['id']}/adjust", ['action' => 'waive', 'reason' => 'Uji pembebasan'], $tAdmin);
    check('Admin membebaskan denda dengan alasan', $r['code'] === 200 && ($r['json']['status'] ?? '') === 'waived');
}
$r = api('POST', "/apartments/$A/run-billing", ['action' => 'rent'], $tAdmin);
check('Terbitkan tagihan sewa manual', $r['code'] === 200 && isset($r['json']['created']), 'kode '.$r['code']);
$r = api('POST', "/apartments/$A/run-billing", ['action' => 'fines'], $tAdmin);
check('Hitung denda manual', $r['code'] === 200);
$r = api('POST', "/apartments/$A/run-billing", ['action' => 'rent'], $tP1);
check('Penghuni ditolak menjalankan penagihan (403)', $r['code'] === 403);
$occ = api('GET', "/apartments/$A/occupancies", null, $tAdmin)['json'] ?? [];
$primary = null;
foreach ($occ as $o) {
    if (($o['unit']['number'] ?? '') === 'A-101') {
        $primary = $o;
    }
}
if ($primary) {
    $r = api('POST', "/apartments/$A/bills", ['occupancy_id' => $primary['id'], 'label' => 'Ganti kartu akses', 'amount' => 75000], $tAdmin);
    check('Tagihan khusus diterbitkan', $r['code'] === 201 && ($r['json']['total'] ?? 0) === 75000, 'kode '.$r['code']);
}

echo "\n== Ekspor ==\n";
foreach (['payments' => 'No. Kwitansi', 'bills' => 'Keterangan', 'occupants' => 'Unit'] as $type => $needle) {
    $r = api('GET', "/apartments/$A/exports/link?type=$type&period=all", null, $tAdmin);
    $url = $r['json']['url'] ?? null;
    $f = $url ? http('GET', $url) : ['code' => 0, 'body' => '', 'type' => ''];
    check("Ekspor CSV $type", $f['code'] === 200 && str_contains($f['type'], 'csv') && str_contains($f['body'], $needle), 'kode '.$f['code']);
}
$r = api('GET', "/apartments/$A/exports/link?type=finance&period=this_month", null, $tOwner);
$f = isset($r['json']['url']) ? http('GET', $r['json']['url']) : ['code' => 0, 'body' => ''];
check('Laporan keuangan PDF', $f['code'] === 200 && str_starts_with($f['body'], '%PDF'), 'kode '.$f['code']);
check('Penghuni ditolak meminta ekspor (403)', api('GET', "/apartments/$A/exports/link?type=payments", null, $tP1)['code'] === 403);

echo "\n== Bergabung: kode apartemen & kode undangan ==\n";
$reg = api('POST', '/register', ['name' => "Calon $suffix", 'email' => "calon$suffix@myhously.test", 'phone' => '081200000000', 'password' => 'password']);
$tNew = $reg['json']['token'] ?? null;
check('Registrasi akun baru', $reg['code'] === 201 && $tNew);
$r = api('GET', '/join/preview?code=GREEN2026', null, $tNew);
check('Pratinjau kode apartemen menampilkan unit tersedia', ($r['json']['mode'] ?? '') === 'apartment' && count($r['json']['units'] ?? []) > 0);
$unitId = $r['json']['units'][0]['id'] ?? null;
check('Pengajuan tanpa memilih unit ditolak (422)', api('POST', '/join', ['code' => 'GREEN2026'], $tNew)['code'] === 422);
$r = api('POST', '/join', ['code' => 'GREEN2026', 'unit_id' => $unitId], $tNew);
check('Pengajuan unit lewat kode apartemen (201)', $r['code'] === 201, 'kode '.$r['code'].' '.substr($r['body'], 0, 120));
$reqId = $r['json']['id'] ?? null;
check('Pengajuan ganda ditolak (422)', api('POST', '/join', ['code' => 'GREEN2026', 'unit_id' => $unitId], $tNew)['code'] === 422);
$r = api('POST', "/apartments/$A/join-requests/$reqId/decide", ['approve' => true, 'start_date' => date('Y-m-d'), 'deposit' => 1000000], $tAdmin);
check('Admin menyetujui pengajuan', $r['code'] === 200, 'kode '.$r['code'].' '.substr($r['body'], 0, 120));
$r = api('GET', '/me', null, $tNew);
check('Akun baru kini penghuni Green Residence', ($r['json']['memberships'][0]['role'] ?? '') === 'tenant');
check('Permintaan yang sudah diproses tidak bisa diproses lagi (422)', api('POST', "/apartments/$A/join-requests/$reqId/decide", ['approve' => true], $tAdmin)['code'] === 422);

$reg2 = api('POST', '/register', ['name' => "Tamu $suffix", 'email' => "tamu$suffix@myhously.test", 'phone' => '081200000001', 'password' => 'password']);
$tNew2 = $reg2['json']['token'] ?? null;
$r = api('GET', '/join/preview?code=GR-304-DEMO', null, $tNew2);
check('Pratinjau kode undangan unit A-304', ($r['json']['mode'] ?? '') === 'invite' && ($r['json']['unit']['number'] ?? '') === 'A-304');
check('Kode undangan kedaluwarsa ditolak (422)', api('GET', '/join/preview?code=GR-OLD-403', null, $tNew2)['code'] === 422);
$r = api('POST', '/join', ['code' => 'GR-304-DEMO'], $tNew2);
check('Gabung dengan kode undangan (201)', $r['code'] === 201, 'kode '.$r['code'].' '.substr($r['body'], 0, 120));
check('Kode undangan sekali pakai (422 saat dipakai lagi)', api('GET', '/join/preview?code=GR-304-DEMO', null, $tNew2)['code'] === 422);
$units = api('GET', "/apartments/$A/units", null, $tAdmin)['json'] ?? [];
$full = null;
foreach ($units as $u) {
    if ($u['number'] === 'A-301') {
        $full = $u;
    }
}
$r = api('POST', "/apartments/$A/invites", ['unit_id' => $full['id'] ?? 0], $tAdmin);
check('Undangan untuk unit yang sudah penuh ditolak (422)', $r['code'] === 422, 'kode '.$r['code']);

echo "\n== Penempatan langsung & akhir masa tinggal ==\n";
$avail = null;
foreach ($units as $u) {
    if ($u['number'] === 'A-403') {
        $avail = $u;
    }
}
$r = api('POST', "/apartments/$A/occupancies", ['email' => 'penghuni15@myhously.test', 'unit_id' => $avail['id'] ?? 0, 'deposit' => 500000], $tAdmin);
check('Admin mendaftarkan penghuni langsung (201)', $r['code'] === 201, 'kode '.$r['code'].' '.substr($r['body'], 0, 120));
$oid = $r['json']['id'] ?? null;
$r = api('POST', "/apartments/$A/occupancies", ['email' => 'tidakada@myhously.test', 'unit_id' => $avail['id'] ?? 0], $tAdmin);
check('Email tidak terdaftar ditolak (422)', $r['code'] === 422);
if ($oid) {
    $r = api('POST', "/apartments/$A/occupancies/$oid/end", null, $tAdmin);
    check('Akhiri masa tinggal tanpa tunggakan', $r['code'] === 200, 'kode '.$r['code'].' '.substr($r['body'], 0, 120));
}
$rr = api('GET', "/apartments/$A/occupancies", null, $tAdmin)['json'] ?? [];
$p10 = null;
foreach ($rr as $o) {
    if (($o['unit']['number'] ?? '') === 'A-303') {
        $p10 = $o;
    }
}
if ($p10) {
    $r = api('POST', "/apartments/$A/occupancies/{$p10['id']}/end", null, $tAdmin);
    check('Akhiri masa tinggal dengan tunggakan meminta konfirmasi (409)', $r['code'] === 409 && ($r['json']['needs_force'] ?? false) === true, 'kode '.$r['code']);
}

echo "\n== Undangan Admin ==\n";
$r = api('POST', "/apartments/$A/admins", ['email' => 'ownerbaru@myhously.test'], $tOwner);
check('Owner mengundang Admin (201, menunggu)', $r['code'] === 201 && ($r['json']['invite_status'] ?? '') === 'pending', 'kode '.$r['code'].' '.substr($r['body'], 0, 120));
check('Admin yang belum menerima belum punya akses (403)', api('GET', "/apartments/$A/dashboard", null, $tNewOwner)['code'] === 403);
$me = api('GET', '/me', null, $tNewOwner)['json'] ?? [];
$invId = $me['admin_invites'][0]['id'] ?? null;
check('Undangan tampil di akun yang diundang', $invId !== null);
if ($invId) {
    $r = api('POST', "/admin-invites/$invId/answer", ['accept' => true], $tNewOwner);
    check('Undangan diterima', $r['code'] === 200);
    check('Setelah menerima, dashboard dapat diakses', api('GET', "/apartments/$A/dashboard", null, $tNewOwner)['code'] === 200);
}
check('Email tidak terdaftar ditolak saat undang Admin (422)', api('POST', "/apartments/$A/admins", ['email' => 'nobody@myhously.test'], $tOwner)['code'] === 422);

echo "\n== Laporan kerusakan (dengan foto) ==\n";
$r = api('POST', "/apartments/$A/reports", null, $tP1, ['fields' => ['title' => 'Uji laporan', 'description' => 'Deskripsi uji dengan foto'], 'files' => [['photos[]', $png, 'uji.png', 'image/png']]]);
check('Penghuni membuat laporan + foto (201)', $r['code'] === 201, 'kode '.$r['code'].' '.substr($r['body'], 0, 160));
$rid = $r['json']['id'] ?? null;
$r = api('GET', "/apartments/$A/reports/$rid", null, $tP1);
check('Laporan memuat 1 foto', count($r['json']['photos'] ?? []) === 1);
$purl = $r['json']['photos'][0]['url'] ?? null;
if ($purl) {
    $f = http('GET', $purl);
    check('Foto laporan dapat diakses', $f['code'] === 200 && str_contains($f['type'], 'image'), 'kode '.$f['code']);
}
$r = api('POST', "/apartments/$A/reports", ['title' => 'x', 'description' => 'y'], $tP1, ['fields' => ['title' => 'Salah', 'description' => 'Bukan gambar'], 'files' => [['photos[]', 'teks biasa', 'uji.txt', 'text/plain']]]);
check('Berkas non-gambar ditolak (422)', $r['code'] === 422, 'kode '.$r['code']);
check('Penghuni lain ditolak membaca laporan (403)', api('GET', "/apartments/$A/reports/$rid", null, $tP11)['code'] === 403);
$r = api('POST', "/apartments/$A/reports/$rid/status", ['status' => 'selesai'], $tAdmin);
check('Loncat status dari Menunggu ke Selesai ditolak (422)', $r['code'] === 422);
$r = api('POST', "/apartments/$A/reports/$rid/status", ['status' => 'ditolak'], $tAdmin);
check('Penolakan tanpa alasan ditolak (422)', $r['code'] === 422);
foreach (['diterima', 'ditangani', 'selesai'] as $st) {
    $r = api('POST', "/apartments/$A/reports/$rid/status", ['status' => $st, 'note' => "Uji $st"], $tAdmin);
    check("Status laporan menjadi $st", $r['code'] === 200 && ($r['json']['status'] ?? '') === $st, 'kode '.$r['code']);
}
$r = api('GET', "/apartments/$A/reports/$rid", null, $tP1);
check('Riwayat status laporan lengkap (4 catatan)', count($r['json']['updates'] ?? []) === 4, (string) count($r['json']['updates'] ?? []));

echo "\n== Profil, foto, pengumuman, fasilitas ==\n";
$r = api('POST', '/me/photo', null, $tP1, ['files' => [['photo', $png, 'avatar.png', 'image/png']]]);
check('Unggah foto profil', $r['code'] === 200 && ! empty($r['json']['photo_url']), 'kode '.$r['code'].' '.substr($r['body'], 0, 120));
$r = api('PUT', '/me', ['hometown' => 'Malang', 'gender' => 'L'], $tP1);
check('Ubah profil (asal daerah, jenis kelamin)', $r['code'] === 200 && ($r['json']['hometown'] ?? '') === 'Malang');
$r = api('PUT', '/me', ['gender' => 'X'], $tP1);
check('Nilai jenis kelamin tidak valid ditolak (422)', $r['code'] === 422);
$r = api('POST', "/apartments/$A/announcements", ['title' => "Uji $suffix", 'body' => 'Isi pengumuman uji', 'category' => 'info'], $tAdmin);
check('Admin membuat pengumuman', $r['code'] === 201);
$r = api('GET', "/apartments/$A/announcements", null, $tP1);
$found = false;
foreach ($r['json'] ?? [] as $a) {
    if (($a['title'] ?? '') === "Uji $suffix") {
        $found = true;
    }
}
check('Penghuni melihat pengumuman baru', $found);
$un = api('GET', '/notifications/unread', null, $tP1);
check('Notifikasi pengumuman masuk ke penghuni', ($un['json']['count'] ?? 0) > 0);
$fac = api('GET', "/apartments/$A/facilities", null, $tP1)['json'] ?? [];
check('Daftar fasilitas bersama (6)', count($fac) === 6, (string) count($fac));
if (! empty($fac[0]['id'])) {
    $r = api('POST', "/apartments/$A/facilities/{$fac[0]['id']}/photo", null, $tAdmin, ['files' => [['photo', $png, 'f.png', 'image/png']]]);
    check('Admin mengunggah foto fasilitas', $r['code'] === 200 && ! empty($r['json']['photo_url']), 'kode '.$r['code']);
}
$r = api('POST', "/apartments/$A/photo", null, $tOwner, ['files' => [['photo', $png, 'a.png', 'image/png']]]);
check('Owner mengunggah foto apartemen', $r['code'] === 200 && ! empty($r['json']['photo_url']));
$r = api('POST', "/apartments/$A/join-code", null, $tAdmin);
check('Kode apartemen dibuat ulang', $r['code'] === 200 && ! empty($r['json']['join_code']));

echo "\n== Unit & tipe unit ==\n";
$types = api('GET', "/apartments/$A/unit-types", null, $tAdmin)['json'] ?? [];
check('Dua tipe unit (Studio, 1 Bedroom)', count($types) === 2);
$r = api('POST', "/apartments/$A/units", ['number' => 'Z-999', 'floor' => 9, 'building' => 'Gedung A', 'unit_type_id' => $types[0]['id'] ?? 0], $tAdmin);
check('Admin menambah unit', $r['code'] === 201, 'kode '.$r['code'].' '.substr($r['body'], 0, 100));
$zid = $r['json']['id'] ?? null;
check('Nomor unit ganda ditolak (422)', api('POST', "/apartments/$A/units", ['number' => 'Z-999', 'floor' => 9, 'unit_type_id' => $types[0]['id'] ?? 0], $tAdmin)['code'] === 422);
check('Admin tidak bisa membuat tipe unit (hanya Owner) (403)', api('POST', "/apartments/$A/unit-types", ['name' => 'Penthouse', 'rent_price' => 9000000], $tAdmin)['code'] === 403);
$r = api('POST', "/apartments/$A/unit-types", ['name' => 'Penthouse', 'rent_price' => 9000000, 'capacity' => 4, 'features' => ['Kolam pribadi']], $tOwner);
check('Owner membuat tipe unit baru', $r['code'] === 201);
if ($zid) {
    check('Admin menghapus unit tanpa riwayat', api('DELETE', "/apartments/$A/units/$zid", null, $tAdmin)['code'] === 200);
}
check('Unit dengan riwayat tidak bisa dihapus (422)', api('DELETE', "/apartments/$A/units/".($units[0]['id'] ?? 0), null, $tAdmin)['code'] === 422);

echo "\n== Permintaan keluar ==\n";
$r = api('POST', "/apartments/$A/move-out", ['desired_date' => date('Y-m-d', strtotime('+10 days'))], $tP6);
check('Permintaan keluar ganda ditolak (422)', $r['code'] === 422, 'kode '.$r['code']);
$r = api('POST', "/apartments/$A/move-out", ['desired_date' => date('Y-m-d', strtotime('+10 days')), 'reason' => 'Uji'], $tP1);
check('Penghuni mengajukan keluar (201)', $r['code'] === 201, 'kode '.$r['code']);
$mid = $r['json']['id'] ?? null;
if ($mid) {
    $r = api('POST', "/apartments/$A/move-out/$mid/decide", ['approve' => false], $tAdmin);
    check('Penolakan permintaan keluar tanpa alasan ditolak (422)', $r['code'] === 422);
    $r = api('POST', "/apartments/$A/move-out/$mid/decide", ['approve' => true], $tAdmin);
    check('Admin menyetujui permintaan keluar', $r['code'] === 200 && ($r['json']['status'] ?? '') === 'approved');
}

echo "\n== Mode demo (geser waktu) ==\n";
$r = api('POST', '/demo/shift', ['days' => 1], $tAdmin);
check('Majukan waktu 1 hari', $r['code'] === 200, 'kode '.$r['code'].' '.substr($r['body'], 0, 150));
$r = api('GET', '/demo', null, $tAdmin);
check('Offset waktu demo = 1', ($r['json']['offset'] ?? 0) === 1);
check('Penghuni ditolak mengubah waktu demo (403)', api('POST', '/demo/shift', ['days' => 1], $tP1)['code'] === 403);
$r = api('POST', '/demo/shift', ['reset' => true], $tAdmin);
check('Waktu demo dikembalikan', $r['code'] === 200 && ($r['json']['demo']['offset'] ?? 1) === 0);

echo "\n== Notifikasi ==\n";
$r = api('GET', '/notifications', null, $tP4);
check('Daftar notifikasi penghuni', $r['code'] === 200 && count($r['json'] ?? []) > 0);
$r = api('POST', '/notifications/read-all', null, $tP4);
check('Tandai semua dibaca', $r['code'] === 200);
check('Notifikasi belum dibaca = 0', (api('GET', '/notifications/unread', null, $tP4)['json']['count'] ?? -1) === 0);

echo "\n==============================\n";
echo "HASIL: $pass lolos, $fail gagal\n";
if ($fail > 0) {
    echo "Yang gagal:\n";
    foreach ($fails as $f) {
        echo " - $f\n";
    }
    exit(1);
}
exit(0);
