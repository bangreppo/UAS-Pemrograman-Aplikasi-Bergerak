# UAS-Pemrograman-Aplikasi-Bergerak
Membuat aplikasi dengan Flutter

# MyHously

Platform manajemen apartemen yang mengintegrasikan pengelolaan antara **Owner / Admin** dan **penghuni** dalam satu aplikasi: unit dan tipe unit, penghuni dan kontrak, tagihan sewa dan layanan tambahan, denda keterlambatan otomatis, pembayaran (simulasi), fasilitas bersama, pengumuman, laporan kerusakan, dan notifikasi.

Tugas UAS Pemrograman Aplikasi Bergerak (individu).

| | |
| --- | --- |
| Nama | Revo Novandra |
| NIM | 24051214211 |
| Judul aplikasi | MyHously |
| Stack | Flutter (frontend) · Laravel 11+ + Sanctum (backend REST API) · MySQL |

## Struktur folder

```
MyHously/
├── backend/    Laravel API (migration, model, controller, service penagihan, seeder demo)
├── frontend/   Aplikasi Flutter (Android + Web/Chrome)
├── setup.sh    Skrip setup satu kali jalan (macOS/Linux)
└── README.md
```

## Prasyarat

PHP 8.2+, Composer, MySQL (XAMPP, port 3307), Flutter SDK, Google Chrome.

### Penagihan otomatis (scheduler)

Tagihan dan denda dijalankan harian oleh scheduler Laravel. Untuk menjalankannya terus-menerus saat demo, buka terminal ketiga:

```bash
cd backend && php artisan schedule:work
```

Perintah manual (bisa dengan tanggal simulasi):

```bash
php artisan myhously:generate-bills --date=2026-11-24   # tagihan sewa bulan berikutnya
php artisan myhously:generate-bills --date=2026-11-30   # tagihan layanan tambahan (akhir bulan)
php artisan myhously:calc-fines
```

Di aplikasi (Dashboard Owner/Admin) ada panel **Penagihan otomatis** dengan tombol untuk menjalankan ketiganya seketika, jadi demo tidak perlu menunggu tanggal.

## Akun demo (kata sandi semua akun: `password`)

| Peran | Email | Keterangan |
| --- | --- | --- |
| Owner | owner@myhously.test | Green Residence Apartment |
| Admin | admin1@myhously.test, admin2@myhously.test | Hak operasional sama |
| Penghuni | penghuni1@myhously.test … penghuni12@myhously.test | 12 penghuni aktif |
| Penghuni terlambat | penghuni4@ (denda 3 hari), penghuni11@ (denda 9 hari) | Untuk demo denda |
| Penghuni baru | penghuni12@myhously.test | Baru bergabung 3 hari lalu |
| Menunggu persetujuan | penghuni13@, penghuni14@ | Permintaan bergabung pending |
| Owner baru | ownerbaru@myhously.test | Belum punya apartemen (tampilan kosong) |
| Apartemen kedua | owner2@, admin3@, penghuni18@, penghuni19@ | Sakura Heights, bukti data terpisah |

Kode undangan aktif untuk uji gabung: **`GR-304-DEMO`** (unit A-304). Daftarkan akun baru lalu pilih *Gabung dengan kode undangan*, kemudian setujui dari akun Admin (tab Unit → Permintaan).

### Data demo Green Residence (16 unit)

* 8 Studio (Rp2.000.000) dan 8 1 Bedroom (Rp2.800.000); 10 unit terisi, 4 tersedia, 2 tidak tersedia.
* 12 penghuni aktif (unit A-301 dan A-302 dihuni 2 orang), 1 mantan penghuni (riwayat tetap ada).
* Tagihan 3 periode: periode lama lunas; periode berjalan 6 lunas, 2 belum bayar (masih masa bayar), 2 terlambat (denda Rp150.000 dan Rp450.000).
* Biaya tetap per unit: service charge Rp150.000, listrik Rp120.000, air Rp60.000.
* Layanan tambahan: gym, sarapan, parkir motor, parkir mobil.
* 8 laporan kerusakan (semua status), 5 pengumuman, 6 fasilitas bersama, permintaan bergabung dan keluar dengan berbagai status.

## Aturan bisnis utama

* **Peran per apartemen**: satu akun bisa menjadi Owner di satu apartemen dan penghuni di apartemen lain. Semua data dipisah per apartemen dan dicek di backend (bukan hanya disembunyikan di aplikasi).
* **Owner** mengatur tipe unit, harga, biaya tetap, jadwal tagihan, fitur yang dipakai, dan menambah Admin. **Admin** mengelola operasional (unit, penghuni, tagihan, laporan, pengumuman) dan boleh mengatur/membebaskan denda.
* **Tipe unit dan fitur bebas per apartemen**: pengelola menentukan sendiri tipe, jumlah unit, dan fitur yang dipakai (fasilitas bersama, layanan tambahan, pengumuman, laporan kerusakan, denda, permintaan keluar). Menu aplikasi menyesuaikan.
* **Bergabung** lewat kode undangan sekali pakai (berlaku 14 hari) → permintaan → disetujui Admin. Kapasitas unit dicek; satu penghuni utama per unit (penanggung tagihan).
* **Kontrak versi ringkas**: tanggal mulai, tanggal berakhir, dan deposit pada data penempatan unit.
* **Tagihan sewa** terbit otomatis tanggal 24 untuk bulan berikutnya (sewa dibayar di muka) dan jatuh tempo tanggal 7. **Tagihan layanan tambahan** dihitung otomatis di akhir bulan dan dapat dibayar mulai tanggal 1. Penghuni boleh membayar sekaligus atau terpisah.
* **Denda** Rp50.000 per hari per unit (satu denda walau dua tagihan terlambat), berjalan otomatis setelah jatuh tempo, berhenti bertambah setelah semua tagihan jatuh tempo lunas, dapat dibebaskan atau diubah Admin/Owner dengan alasan tercatat.
* **Nominal tagihan disalin** ke item tagihan, jadi perubahan harga hanya berlaku untuk tagihan berikutnya.
* **Pembayaran** adalah simulasi (Transfer Bank, QRIS, Virtual Account, E-Wallet) dengan bukti pembayaran di aplikasi.
* **Laporan kerusakan** punya alur status: Menunggu → Diterima/Ditolak → Ditangani → Selesai, dengan riwayat dan notifikasi ke pelapor.

## Ringkasan API

Semua endpoint di bawah `/api`, autentikasi token Laravel Sanctum (`Authorization: Bearer ...`).

* Akun: `POST /register`, `POST /login`, `GET|PUT /me`, `POST /logout`
* Gabung: `GET /join/preview?code=`, `POST /join`, `POST /join-requests/{id}/cancel`
* Apartemen: `GET|POST /apartments`, `GET|PUT /apartments/{id}`, `GET /apartments/{id}/dashboard`, `POST /apartments/{id}/run-billing`, `GET|POST|DELETE /apartments/{id}/admins`
* Unit: `/unit-types`, `/units`, `/invites`, `/join-requests`, `/occupancies`, `/move-out`
* Keuangan: `/services`, `/bills`, `/fines`, `/payments`
* Komunitas: `/announcements`, `/facilities`, `/reports`, `/notifications`

## Batasan versi ini

* Pembayaran bersifat simulasi (tanpa payment gateway); notifikasi hanya di dalam aplikasi (tanpa push).
* Laporan kerusakan belum mendukung unggah foto; belum ada ekspor CSV/PDF.
* Kontrak sewa tidak berupa dokumen terpisah (hanya tanggal mulai, berakhir, dan deposit).

## Pemecahan masalah

* **"Tidak dapat terhubung ke server"**: pastikan `php artisan serve` berjalan di port 8000.
* **Gagal migrasi / koneksi database**: cek MySQL XAMPP menyala, port (3307), dan database `myhously` ada; ubah `backend/.env` bila perlu lalu `php artisan migrate:fresh --seed`.
* **Error CORS di Chrome**: jalankan `php artisan config:publish cors` di folder backend lalu muat ulang.
