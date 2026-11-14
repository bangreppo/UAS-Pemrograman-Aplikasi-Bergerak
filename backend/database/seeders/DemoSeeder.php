<?php

namespace Database\Seeders;

use App\Models\Announcement;
use App\Models\Apartment;
use App\Models\ApartmentMember;
use App\Models\AppNotification;
use App\Models\Bill;
use App\Models\Facility;
use App\Models\Fine;
use App\Models\Invite;
use App\Models\JoinRequest;
use App\Models\MoveOutRequest;
use App\Models\Occupancy;
use App\Models\Payment;
use App\Models\PaymentItem;
use App\Models\Report;
use App\Models\ReportUpdate;
use App\Models\Service;
use App\Models\ServiceSubscription;
use App\Models\Unit;
use App\Models\UnitType;
use App\Models\User;
use App\Services\BillingService;
use Carbon\Carbon;
use Illuminate\Database\Seeder;

class DemoSeeder extends Seeder
{
    protected BillingService $svc;
    protected Carbon $today;
    protected array $mod = ['facilities', 'services', 'announcements', 'reports', 'fines', 'move_out'];

    protected function user(string $name, string $email, string $phone): User
    {
        return User::create(['name' => $name, 'email' => $email, 'phone' => $phone, 'password' => 'password']);
    }

    protected function payBills(Apartment $a, Occupancy $o, array $bills, Carbon $at, string $method = 'Transfer Bank', array $fines = []): Payment
    {
        $total = collect($bills)->sum('total') + collect($fines)->sum('amount');
        $p = Payment::create(['apartment_id' => $a->id, 'user_id' => $o->user_id, 'unit_id' => $o->unit_id, 'method' => $method, 'amount' => $total, 'paid_at' => $at]);
        $p->update(['receipt_no' => 'MYH-'.$at->format('Ymd').'-'.str_pad((string) $p->id, 4, '0', STR_PAD_LEFT)]);
        foreach ($bills as $b) {
            PaymentItem::create(['payment_id' => $p->id, 'payable_type' => 'bill', 'payable_id' => $b->id, 'amount' => $b->total]);
            $b->update(['status' => 'paid', 'paid_at' => $at]);
        }
        foreach ($fines as $f) {
            PaymentItem::create(['payment_id' => $p->id, 'payable_type' => 'fine', 'payable_id' => $f->id, 'amount' => $f->amount]);
            $f->update(['status' => 'paid', 'paid_at' => $at]);
        }

        return $p;
    }

    public function run(): void
    {
        $this->svc = new BillingService();
        $this->svc->silent = true;
        $this->today = now()->startOfDay();
        $t = $this->today;

        // ---------- Akun ----------
        $owner = $this->user('Hendra Wijaya', 'owner@myhously.test', '081230000001');
        $admin1 = $this->user('Sari Lestari', 'admin1@myhously.test', '081230000002');
        $admin2 = $this->user('Dedi Kurniawan', 'admin2@myhously.test', '081230000003');
        $names = ['Budi Santoso', 'Rina Maharani', 'Agus Prasetyo', 'Dewi Anggraini', 'Fajar Nugroho', 'Putri Ayu Lestari', 'Rizky Ramadhan', 'Nadia Safitri', 'Yoga Pratama', 'Maya Kusuma', 'Eko Wahyudi', 'Sinta Permata', 'Ahmad Fauzi', 'Citra Dewi', 'Bagas Setiawan', 'Lina Marlina', 'Hadi Gunawan', 'Anton Wijaya', 'Mega Putri'];
        $p = [];
        foreach ($names as $i => $n) {
            $p[$i + 1] = $this->user($n, 'penghuni'.($i + 1).'@myhously.test', '0812400'.str_pad((string) ($i + 1), 5, '0', STR_PAD_LEFT));
        }
        $this->user('Owner Baru', 'ownerbaru@myhously.test', '081230000099');

        // ---------- Green Residence Apartment ----------
        $a = Apartment::create([
            'owner_id' => $owner->id, 'name' => 'Green Residence Apartment', 'address' => 'Jl. Raya Darmo No. 88, Surabaya', 'city' => 'Surabaya',
            'contact' => '0812-3000-0002 (Pengelola)', 'description' => 'Apartemen fiktif untuk demonstrasi MyHously: 4 lantai, 16 unit.',
            'rules' => "1. Jam kunjungan tamu pukul 08.00–21.00.\n2. Tamu menginap wajib lapor ke pengelola.\n3. Dilarang merokok di dalam unit dan area bersama.\n4. Hewan peliharaan hanya dengan izin tertulis pengelola.\n5. Pembayaran sewa paling lambat tanggal 7 setiap bulan; keterlambatan dikenai denda per hari.\n6. Jaga ketenangan pukul 22.00–06.00.",
            'modules' => $this->mod, 'service_fee' => 150000, 'electricity_fee' => 120000, 'water_fee' => 60000, 'late_fee_per_day' => 50000, 'rent_issue_day' => 24, 'due_day' => 7,
        ]);
        ApartmentMember::create(['apartment_id' => $a->id, 'user_id' => $owner->id, 'role' => 'owner']);
        ApartmentMember::create(['apartment_id' => $a->id, 'user_id' => $admin1->id, 'role' => 'admin']);
        ApartmentMember::create(['apartment_id' => $a->id, 'user_id' => $admin2->id, 'role' => 'admin']);

        $studio = UnitType::create(['apartment_id' => $a->id, 'name' => 'Studio', 'area' => 24, 'bedrooms' => 0, 'bathrooms' => 1, 'capacity' => 2, 'rent_price' => 2000000, 'features' => ['AC', 'Tempat tidur', 'Lemari', 'Meja kerja', 'Kamar mandi dalam', 'Wi-Fi']]);
        $br1 = UnitType::create(['apartment_id' => $a->id, 'name' => '1 Bedroom', 'area' => 38, 'bedrooms' => 1, 'bathrooms' => 1, 'capacity' => 2, 'rent_price' => 2800000, 'features' => ['AC', 'Tempat tidur', 'Lemari', 'Meja kerja', 'Kamar mandi dalam', 'Dapur', 'Balkon', 'Wi-Fi']]);

        $units = [];
        foreach ([1, 2, 3, 4] as $floor) {
            foreach ([1, 2, 3, 4] as $idx) {
                $num = 'A-'.$floor.'0'.$idx;
                $units[$num] = Unit::create(['apartment_id' => $a->id, 'unit_type_id' => $floor <= 2 ? $studio->id : $br1->id, 'number' => $num, 'floor' => $floor, 'status' => 'available']);
            }
        }
        foreach (['A-204', 'A-404'] as $n) {
            $units[$n]->update(['status' => 'maintenance']);
        }

        // penempatan: unit => [[penghuni, utama?, bulan lalu mulai]]
        $plan = [
            'A-101' => [[1, true, 8]], 'A-102' => [[2, true, 6]], 'A-103' => [[3, true, 5]], 'A-104' => [[4, true, 5]],
            'A-201' => [[5, true, 4]], 'A-202' => [[6, true, 3]],
            'A-301' => [[7, true, 7], [8, false, 7]], 'A-302' => [[9, true, 4], [10, false, 2]], 'A-303' => [[11, true, 3]],
            'A-401' => [[12, true, 0]],
        ];
        $occ = [];
        foreach ($plan as $num => $people) {
            $unit = $units[$num];
            $unit->update(['status' => 'occupied']);
            $type = $unit->unit_type_id === $studio->id ? $studio : $br1;
            foreach ($people as [$pi, $primary, $months]) {
                $start = $months === 0 ? $t->copy()->subDays(3) : $t->copy()->subMonthsNoOverflow($months);
                $occ[$pi] = Occupancy::create([
                    'apartment_id' => $a->id, 'unit_id' => $unit->id, 'user_id' => $p[$pi]->id, 'is_primary' => $primary,
                    'start_date' => $start->toDateString(), 'end_date' => $start->copy()->addYear()->toDateString(), 'deposit' => $primary ? $type->rent_price : 0, 'status' => 'active',
                ]);
                ApartmentMember::create(['apartment_id' => $a->id, 'user_id' => $p[$pi]->id, 'role' => 'tenant']);
            }
        }
        // mantan penghuni
        $ex = Occupancy::create(['apartment_id' => $a->id, 'unit_id' => $units['A-203']->id, 'user_id' => $p[17]->id, 'is_primary' => true, 'start_date' => $t->copy()->subMonthsNoOverflow(10)->toDateString(), 'end_date' => $t->copy()->subMonthNoOverflow()->toDateString(), 'deposit' => 2000000, 'status' => 'ended', 'ended_at' => $t->copy()->subMonthNoOverflow()]);
        ApartmentMember::create(['apartment_id' => $a->id, 'user_id' => $p[17]->id, 'role' => 'tenant', 'is_active' => false]);
        MoveOutRequest::create(['apartment_id' => $a->id, 'occupancy_id' => $ex->id, 'user_id' => $p[17]->id, 'desired_date' => $t->copy()->subMonthNoOverflow()->toDateString(), 'reason' => 'Pindah tugas ke luar kota.', 'status' => 'approved', 'note' => 'Disetujui. Deposit dikembalikan.']);
        MoveOutRequest::create(['apartment_id' => $a->id, 'occupancy_id' => $occ[6]->id, 'user_id' => $p[6]->id, 'desired_date' => $t->copy()->addDays(20)->toDateString(), 'reason' => 'Pindah ke kota lain karena pekerjaan.', 'status' => 'pending']);

        // ---------- Layanan tambahan ----------
        $gym = Service::create(['apartment_id' => $a->id, 'name' => 'Member Gym', 'price' => 150000, 'description' => 'Akses gym tanpa batas.']);
        $sarapan = Service::create(['apartment_id' => $a->id, 'name' => 'Sarapan Harian', 'price' => 300000, 'description' => 'Sarapan di lobi setiap hari.']);
        $motor = Service::create(['apartment_id' => $a->id, 'name' => 'Parkir Motor', 'price' => 100000]);
        $mobil = Service::create(['apartment_id' => $a->id, 'name' => 'Parkir Mobil', 'price' => 250000]);
        foreach ([[$gym, [1, 5, 7, 11]], [$sarapan, [2, 9]], [$motor, [1, 3, 4]], [$mobil, [7]]] as [$svc, $list]) {
            foreach ($list as $pi) {
                ServiceSubscription::create(['service_id' => $svc->id, 'occupancy_id' => $occ[$pi]->id]);
            }
        }

        // ---------- Tagihan ----------
        $primaries = array_filter([1, 2, 3, 4, 5, 6, 7, 9, 11, 12], fn ($i) => true);
        foreach ($primaries as $pi) {
            $o = $occ[$pi];
            $items = $this->svc->rentItems($a, $o);
            $cycles = $pi === 12 ? [0] : [2, 1, 0];
            foreach ($cycles as $c) {
                $period = $t->copy()->startOfMonth()->subMonthsNoOverflow($c);
                $label = 'Sewa '.BillingService::bulan($period);
                if ($c > 0) {
                    $due = $period->copy()->day(7);
                    $bill = $this->svc->make($a, $o, 'rent', $period, $label, $due->copy()->subDays(14), $due->copy()->subDays(14), $due, $items);
                    $late = $pi === 3 && $c === 1;
                    $fine = null;
                    if ($late) {
                        $fine = Fine::create(['apartment_id' => $a->id, 'unit_id' => $o->unit_id, 'occupancy_id' => $o->id, 'user_id' => $o->user_id, 'days' => 2, 'amount' => 100000, 'started_on' => $due->copy()->addDay()->toDateString(), 'status' => 'due']);
                    }
                    $this->payBills($a, $o, [$bill], $late ? $due->copy()->addDays(2) : $due->copy()->subDays(rand(2, 6)), ['Transfer Bank', 'QRIS', 'Virtual Account', 'E-Wallet'][$pi % 4], $fine ? [$fine] : []);
                } else {
                    $issued = $t->copy()->subDays(10);
                    $dueCur = match ($pi) {
                        4 => $t->copy()->subDays(3),
                        11 => $t->copy()->subDays(9),
                        default => $t->copy()->addDays(4),
                    };
                    $bill = $this->svc->make($a, $o, 'rent', $period, $label, $issued, $issued, $dueCur, $items);
                    if (in_array($pi, [1, 2, 3, 5, 7, 9])) {
                        $this->payBills($a, $o, [$bill], $t->copy()->subDays(rand(1, 6)), ['Transfer Bank', 'QRIS', 'Virtual Account', 'E-Wallet'][$pi % 4]);
                    }
                }
            }
        }
        // tagihan layanan tambahan
        foreach ([1, 2, 3, 4, 5, 7, 9, 11] as $pi) {
            $o = $occ[$pi];
            $subs = ServiceSubscription::with('service')->where('occupancy_id', $o->id)->get();
            if ($subs->isEmpty()) {
                continue;
            }
            $items = $subs->map(fn ($s) => ['service', $s->service->name, (int) $s->service->price])->all();
            $period = $t->copy()->startOfMonth()->subMonthsNoOverflow(2);
            $due = $period->copy()->addMonthNoOverflow()->day(7);
            $b1 = $this->svc->make($a, $o, 'extras', $period, 'Layanan tambahan '.BillingService::bulan($period), $due->copy()->subDays(7), $due->copy()->subDays(7), $due, $items);
            $this->payBills($a, $o, [$b1], $due->copy()->subDays(3));
            if (in_array($pi, [2, 7])) {
                $per2 = $t->copy()->startOfMonth()->subMonthNoOverflow();
                $this->svc->make($a, $o, 'extras', $per2, 'Layanan tambahan '.BillingService::bulan($per2), $t->copy()->subDays(5), $t->copy()->subDays(5), $t->copy()->addDays(4), $items);
            } else {
                $per2 = $t->copy()->startOfMonth()->subMonthNoOverflow();
                $dd = $per2->copy()->addMonthNoOverflow()->day(7);
                $b2 = $this->svc->make($a, $o, 'extras', $per2, 'Layanan tambahan '.BillingService::bulan($per2), $t->copy()->subDays(12), $t->copy()->subDays(12), $dd, $items);
                $this->payBills($a, $o, [$b2], $t->copy()->subDays(rand(2, 7)));
            }
        }
        $this->svc->calcFines($a, $t);

        // ---------- Permintaan bergabung ----------
        $mk = function (string $code, string $unit, ?Carbon $used, Carbon $exp) use ($a, $units, $admin1, $br1, $studio) {
            return Invite::create(['apartment_id' => $a->id, 'unit_id' => $units[$unit]->id, 'code' => $code, 'is_primary' => true, 'start_date' => $this->today->toDateString(), 'deposit' => $units[$unit]->unit_type_id === $studio->id ? 2000000 : 2800000, 'expires_at' => $exp, 'used_at' => $used, 'created_by' => $admin1->id]);
        };
        $reqs = [[13, 'A-304', 'pending'], [14, 'A-402', 'pending'], [15, 'A-403', 'rejected'], [16, 'A-304', 'cancelled']];
        foreach ($reqs as $i => [$pi, $un, $st]) {
            $inv = $mk('MYH-DEMO'.($i + 1).'X', $un, $t->copy()->subDays(5 - $i), $t->copy()->addDays(10));
            JoinRequest::create(['apartment_id' => $a->id, 'unit_id' => $units[$un]->id, 'user_id' => $p[$pi]->id, 'invite_id' => $inv->id, 'is_primary' => true, 'start_date' => $t->toDateString(), 'deposit' => $inv->deposit, 'status' => $st, 'reject_reason' => $st === 'rejected' ? 'Unit sudah dipesan oleh calon penghuni lain.' : null]);
        }
        $invUsed = $mk('MYH-DEMO5X', 'A-401', $t->copy()->subDays(4), $t->copy()->addDays(5));
        JoinRequest::create(['apartment_id' => $a->id, 'unit_id' => $units['A-401']->id, 'user_id' => $p[12]->id, 'invite_id' => $invUsed->id, 'is_primary' => true, 'start_date' => $t->copy()->subDays(3)->toDateString(), 'deposit' => 2800000, 'status' => 'approved']);
        $mk('GR-304-DEMO', 'A-304', null, $t->copy()->addDays(30));
        $mk('GR-OLD-403', 'A-403', null, $t->copy()->subDays(3));

        // ---------- Fasilitas bersama ----------
        $fac = [];
        foreach ([
            ['Kolam Renang', 'available', '06.00–21.00', 'Lantai 1, area belakang', 'Wajib mandi sebelum berenang. Anak di bawah 12 tahun didampingi.'],
            ['Gym', 'available', '05.00–22.00', 'Lantai 1', 'Gunakan handuk dan rapikan peralatan setelah dipakai.'],
            ['Area Parkir', 'available', '24 jam', 'Basement', 'Parkir hanya untuk penghuni terdaftar.'],
            ['Lobi & Resepsionis', 'available', '24 jam', 'Lantai 1', null],
            ['Lift', 'maintenance', '24 jam', 'Gedung utama', 'Gunakan tangga darurat selama perbaikan.'],
            ['Ruang Serbaguna', 'closed', '08.00–21.00', 'Lantai 2', 'Penggunaan atas izin pengelola.'],
        ] as [$n, $st, $h, $loc, $rules]) {
            $fac[$n] = Facility::create(['apartment_id' => $a->id, 'name' => $n, 'status' => $st, 'hours' => $h, 'location' => $loc, 'rules' => $rules, 'description' => null]);
        }

        // ---------- Pengumuman ----------
        foreach ([
            ['Selamat datang di Green Residence', 'Terima kasih telah bergabung. Silakan lengkapi profil Anda dan baca peraturan apartemen pada menu Informasi.', 'info', false, 45],
            ['Aturan jam kunjungan tamu', 'Mulai bulan ini, tamu wajib melapor di resepsionis dan kunjungan berakhir pukul 21.00.', 'penting', false, 38],
            ['Pemadaman air Sabtu pagi', 'Akan ada pemadaman air pada hari Sabtu pukul 09.00–12.00 untuk pembersihan tangki. Mohon menampung air secukupnya.', 'perawatan', false, 2],
            ['Perbaikan lift lantai 2', 'Lift sedang dalam perbaikan. Teknisi vendor dijadwalkan menyelesaikan dalam beberapa hari. Gunakan tangga darurat.', 'perawatan', true, 1],
            ['Pengingat pembayaran sewa', 'Pembayaran sewa paling lambat tanggal 7. Keterlambatan dikenai denda Rp50.000 per hari per unit.', 'pembayaran', false, 4],
        ] as [$title, $body, $cat, $pin, $ago]) {
            Announcement::create(['apartment_id' => $a->id, 'user_id' => $admin1->id, 'title' => $title, 'body' => $body, 'category' => $cat, 'is_pinned' => $pin, 'created_at' => $t->copy()->subDays($ago)->addHours(9), 'updated_at' => $t->copy()->subDays($ago)->addHours(9)]);
        }

        // ---------- Laporan ----------
        $reportData = [
            [1, 'A-101', null, 'AC tidak dingin', 'AC di kamar hanya mengeluarkan angin biasa sejak kemarin.', [['menunggu', 'Laporan dikirim.', 1]], 1],
            [6, 'A-202', null, 'Keran dapur bocor', 'Air menetes terus dari bawah keran dapur.', [['menunggu', 'Laporan dikirim.', 2]], 2],
            [2, 'A-102', null, 'Lampu kamar mandi mati', 'Lampu kamar mandi tidak menyala meski sudah dicoba ganti saklar.', [['menunggu', 'Laporan dikirim.', 4], ['diterima', 'Diterima. Teknisi dijadwalkan hari Jumat.', 3]], 3],
            [9, 'A-302', null, 'Pintu balkon sulit dikunci', 'Kunci pintu balkon agak seret.', [['menunggu', 'Laporan dikirim.', 6], ['ditolak', 'Pintu sudah diperiksa dan masih berfungsi normal. Silakan ajukan ulang jika masih bermasalah.', 5]], 5],
            [5, 'A-201', null, 'Wi-Fi unit sering putus', 'Koneksi Wi-Fi di unit terputus beberapa kali sehari.', [['menunggu', 'Laporan dikirim.', 7], ['diterima', 'Diterima.', 6], ['ditangani', 'Teknisi jaringan sedang memeriksa router lantai 2.', 4]], 4],
            [3, null, 'Lift', 'Lift lantai 2 berhenti mendadak', 'Lift berhenti di antara lantai 1 dan 2 lalu mati.', [['menunggu', 'Laporan dikirim.', 3], ['diterima', 'Diterima.', 2], ['ditangani', 'Teknisi vendor lift dijadwalkan besok pagi.', 1]], 1],
            [11, 'A-303', null, 'Kloset tersumbat', 'Kloset tersumbat dan air meluap.', [['menunggu', 'Laporan dikirim.', 12], ['diterima', 'Diterima.', 11], ['ditangani', 'Teknisi sudah datang.', 10], ['selesai', 'Sudah diperbaiki dan dicek bersama penghuni.', 9]], 9],
            [7, null, 'Area Parkir', 'Lampu area parkir mati', 'Dua lampu di sisi kiri basement mati sehingga gelap.', [['menunggu', 'Laporan dikirim.', 15], ['diterima', 'Diterima.', 14], ['ditangani', 'Penggantian lampu dijadwalkan.', 13], ['selesai', 'Lampu sudah diganti.', 11]], 11],
        ];
        foreach ($reportData as [$pi, $un, $fn, $title, $desc, $steps, $ago]) {
            $last = end($steps);
            $rep = Report::create([
                'apartment_id' => $a->id, 'user_id' => $p[$pi]->id, 'unit_id' => $un ? $units[$un]->id : null, 'facility_id' => $fn ? $fac[$fn]->id : null,
                'title' => $title, 'description' => $desc, 'status' => $last[0], 'reject_reason' => $last[0] === 'ditolak' ? $last[1] : null,
                'created_at' => $t->copy()->subDays($steps[0][2])->addHours(10), 'updated_at' => $t->copy()->subDays($last[2])->addHours(10),
            ]);
            foreach ($steps as [$st, $note, $d]) {
                ReportUpdate::create(['report_id' => $rep->id, 'user_id' => $st === 'menunggu' ? $p[$pi]->id : $admin1->id, 'status' => $st, 'note' => $note, 'created_at' => $t->copy()->subDays($d)->addHours(10), 'updated_at' => $t->copy()->subDays($d)->addHours(10)]);
            }
        }

        // ---------- Notifikasi contoh ----------
        foreach ([1, 2, 3, 5, 7, 9] as $pi) {
            AppNotification::create(['user_id' => $p[$pi]->id, 'apartment_id' => $a->id, 'title' => 'Pengumuman baru', 'body' => 'Perbaikan lift lantai 2', 'type' => 'announcement']);
            AppNotification::create(['user_id' => $p[$pi]->id, 'apartment_id' => $a->id, 'title' => 'Pembayaran berhasil dicatat', 'body' => 'Pembayaran sewa bulan berjalan telah dicatat.', 'type' => 'payment', 'read_at' => now()]);
        }
        foreach ([4, 11] as $pi) {
            AppNotification::create(['user_id' => $p[$pi]->id, 'apartment_id' => $a->id, 'title' => 'Denda keterlambatan berjalan', 'body' => 'Tagihan Anda melewati jatuh tempo. Denda Rp50.000 per hari berjalan.', 'type' => 'fine']);
        }
        foreach ([$admin1, $admin2, $owner] as $u) {
            AppNotification::create(['user_id' => $u->id, 'apartment_id' => $a->id, 'title' => 'Permintaan bergabung baru', 'body' => 'Ada 2 permintaan bergabung yang menunggu.', 'type' => 'join']);
            AppNotification::create(['user_id' => $u->id, 'apartment_id' => $a->id, 'title' => 'Laporan baru', 'body' => 'AC tidak dingin (A-101)', 'type' => 'report']);
        }

        // ---------- Apartemen kedua (bukti data terpisah) ----------
        $o2 = $this->user('Kartika Sari', 'owner2@myhously.test', '081230000010');
        $ad3 = $this->user('Joko Susilo', 'admin3@myhously.test', '081230000011');
        $b = Apartment::create(['owner_id' => $o2->id, 'name' => 'Sakura Heights', 'address' => 'Jl. Ngagel Jaya No. 12, Surabaya', 'city' => 'Surabaya', 'modules' => ['facilities', 'announcements', 'reports', 'fines'], 'service_fee' => 100000, 'electricity_fee' => 90000, 'water_fee' => 50000, 'late_fee_per_day' => 25000]);
        ApartmentMember::create(['apartment_id' => $b->id, 'user_id' => $o2->id, 'role' => 'owner']);
        ApartmentMember::create(['apartment_id' => $b->id, 'user_id' => $ad3->id, 'role' => 'admin']);
        $st = UnitType::create(['apartment_id' => $b->id, 'name' => 'Studio Standar', 'area' => 22, 'capacity' => 2, 'rent_price' => 1500000, 'features' => ['AC', 'Kamar mandi dalam']]);
        $su = [];
        foreach (['S-101', 'S-102', 'S-103', 'S-104'] as $i => $n) {
            $su[$n] = Unit::create(['apartment_id' => $b->id, 'unit_type_id' => $st->id, 'number' => $n, 'floor' => 1, 'status' => $i < 2 ? 'occupied' : 'available']);
        }
        foreach ([[18, 'S-101'], [19, 'S-102']] as [$pi, $n]) {
            $o = Occupancy::create(['apartment_id' => $b->id, 'unit_id' => $su[$n]->id, 'user_id' => $p[$pi]->id, 'is_primary' => true, 'start_date' => $t->copy()->subMonthsNoOverflow(2)->toDateString(), 'deposit' => 1500000, 'status' => 'active']);
            ApartmentMember::create(['apartment_id' => $b->id, 'user_id' => $p[$pi]->id, 'role' => 'tenant']);
            $this->svc->make($b, $o, 'rent', $t->copy()->startOfMonth(), 'Sewa '.BillingService::bulan($t), $t->copy()->subDays(8), $t->copy()->subDays(8), $t->copy()->addDays(5), $this->svc->rentItems($b, $o));
        }
        Announcement::create(['apartment_id' => $b->id, 'user_id' => $ad3->id, 'title' => 'Selamat datang di Sakura Heights', 'body' => 'Apartemen ini terpisah dari Green Residence; data keduanya tidak saling terlihat.', 'category' => 'info']);

        // buang notifikasi otomatis yang tidak relevan untuk apartemen kedua
        AppNotification::where('apartment_id', $b->id)->delete();
    }
}
