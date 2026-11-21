# MyHously

**Platform manajemen apartemen** yang menyatukan pengelola yaitu Owner,Admin dan penghuni dalam satu aplikasi: unit, penghuni, tagihan sewa, denda, pembayaran, fasilitas, pengumuman, dan laporan kerusakan, semuanya digital dan terintegrasi.

Tugas UAS Pemrograman Aplikasi Bergerak (individu).

| | |
| --- | --- |
| Nama / NIM | Revo Novandra / 24051214211 |
| Judul | MyHously |
| Teknologi | Flutter (Web + Android) · Laravel + Sanctum (REST API) · MySQL · dompdf |
| Skala | 21 tabel · 78 endpoint API · 112 pemeriksaan uji otomatis |

## Masalah yang diselesaikan

Pengelolaan apartemen sering terpecah: tagihan dicatat manual, pembayaran dan denda dihitung sendiri, laporan kerusakan lewat chat. MyHously mengotomatiskan penagihan dan denda, memberi penghuni satu tempat untuk membayar dan melapor, dan memberi pengelola ringkasan keuangan serta ekspor laporan.

## Peran

| Peran | Yang dilakukan |
| --- | --- |
| **Owner** | Membuat apartemen, menentukan tipe unit, harga, biaya, jadwal tagihan, dan fitur; mengundang Admin; melihat dashboard keuangan |
| **Admin** | Operasional harian: unit, penghuni, tagihan, denda, laporan, pengumuman, ekspor |
| **Penghuni** | Melihat unit dan kontrak, membayar tagihan, melapor kerusakan, membaca pengumuman, mengajukan keluar |

Peran melekat **per apartemen**: satu akun bisa menjadi Owner di satu apartemen dan penghuni di apartemen lain.

## Fitur unggulan

- **Pengaturan apartemen fleksibel**: tipe unit dan jumlah unit dibuat bebas, fitur dipilih sendiri (fasilitas bersama, layanan tambahan, pengumuman, laporan, denda, permintaan keluar). Menu aplikasi menyesuaikan.
- **Tiga cara bergabung**: kode undangan sekali pakai, kode apartemen (calon penghuni memilih unit lalu disetujui Admin), atau didaftarkan langsung oleh Admin. Kapasitas unit dicek otomatis.
- **Tagihan otomatis** oleh scheduler: sewa terbit tanggal 24 (jatuh tempo tanggal 7), layanan tambahan (gym, sarapan, parkir) dihitung akhir bulan, pengingat jatuh tempo, penghuni bisa bayar sekaligus atau terpisah.
- **Denda otomatis** Rp50.000 per hari per unit (satu denda walau dua tagihan terlambat); Admin/Owner dapat mengubah atau membebaskannya dengan alasan tercatat.
- **Pembayaran** (simulasi) dengan bukti bayar dan **kwitansi PDF**; **ekspor** laporan keuangan PDF dan CSV (pembayaran, tagihan, penghuni).
- **Laporan kerusakan berfoto** dengan alur status Menunggu → Diterima/Ditolak → Ditangani → Selesai, lengkap riwayat dan notifikasi.
- **Mode demo geser waktu**: memajukan tanggal aplikasi agar tagihan, pengingat, dan denda bisa didemokan tanpa menunggu.
- **Tampilan modern dan responsif**: navigasi bawah di HP, navigasi samping di layar lebar.

## Arsitektur singkat

```
Flutter (frontend)  ⇄  REST API JSON (Laravel + Sanctum)  ⇄  MySQL
                                   │
                    Service penagihan + scheduler harian + dompdf
```

- Backend berlapis: Route → Controller → Service (`BillingService`) → Model; aturan akses di backend, bukan hanya disembunyikan di aplikasi.
- Integritas: transaksi database saat pembayaran, nominal tagihan disalin ke item tagihan (perubahan harga tidak mengubah tagihan lama), unduhan PDF/CSV lewat tautan bertanda tangan berumur 10 menit.
- Data tiap apartemen terpisah penuh (terbukti pada data demo dua apartemen).

## Struktur folder

```
MyHously/
├── backend/    Laravel API (migration, model, controller, service, seeder, tests/smoke.php)
├── frontend/   Aplikasi Flutter
├── docs/       PANDUAN-TEKNIS.md (detail instalasi, API, pemecahan masalah)
├── setup.sh · run.sh · verify.sh · reset-data.sh
```

## Cara menjalankan

Prasyarat: PHP 8.2+, Composer, MySQL (XAMPP, port 3307), Flutter SDK, Chrome.

```bash
./setup.sh      # pasang backend + frontend, buat database MySQL, isi data demo (sekali saja)
./run.sh        # jalankan backend, scheduler, dan aplikasi di Chrome
./verify.sh     # (opsional) uji otomatis: lint, migrasi, 112 pemeriksaan API, flutter analyze
```

Pengaturan database (port, nama, user) ada di bagian atas `setup.sh`. Panduan lengkap: `docs/PANDUAN-TEKNIS.md`.

## Akun demo (kata sandi semua akun: `password`)

| Peran | Email |
| --- | --- |
| Owner | owner@myhously.test |
| Admin | admin1@myhously.test |
| Penghuni | penghuni1@myhously.test |
| Penghuni terlambat (ada denda) | penghuni4@myhously.test |
| Owner baru (belum punya apartemen) | ownerbaru@myhously.test |

Kode uji gabung: `GREEN2026` (kode apartemen) dan `GR-304-DEMO` (undangan unit A-304). Data demo: Green Residence Apartment dengan 16 unit, 12 penghuni, tagihan tiga periode, denda berjalan, dan laporan kerusakan semua status; plus apartemen kedua (Sakura Heights) untuk membuktikan data terpisah.
