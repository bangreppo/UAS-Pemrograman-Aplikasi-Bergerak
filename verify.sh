#!/usr/bin/env bash
# MyHously - verifikasi menyeluruh (jalankan SETELAH ./setup.sh).
#   ./verify.sh            -> lint PHP, rute, migrasi+seeder (MySQL), uji API, flutter analyze
#   ./verify.sh --build    -> ditambah `flutter build web` (lebih lama)
# Hasil lengkap disimpan di verify.log. Jika ada yang gagal, kirim isi verify.log ke Claude.
cd "$(dirname "$0")"
ROOT="$PWD"
LOG="$ROOT/verify.log"
PORT=8099
: > "$LOG"

XAMPP_BIN=/Applications/XAMPP/xamppfiles/bin
if ! command -v php >/dev/null 2>&1 && [ -x "$XAMPP_BIN/php" ]; then export PATH="$XAMPP_BIN:$PATH"; fi

say() { echo -e "$*" | tee -a "$LOG"; }
section() { say "\n=== $* ==="; }
FAILS=0
fail() { FAILS=$((FAILS + 1)); say "  [GAGAL] $*"; }
ok() { say "  [OK]    $*"; }

section "Prasyarat"
command -v php >/dev/null 2>&1 && ok "php $(php -r 'echo PHP_VERSION;')" || { fail "php tidak ditemukan"; }
[ -f backend/artisan ] && ok "proyek Laravel ada (backend/artisan)" || { fail "backend belum dibuat. Jalankan ./setup.sh dulu"; say "\nVERIFIKASI BERHENTI."; exit 1; }
command -v flutter >/dev/null 2>&1 && ok "flutter ditemukan" || say "  (flutter tidak ditemukan: langkah frontend dilewati)"
grep -q '^DB_CONNECTION=mysql' backend/.env && ok "database: MySQL ($(grep '^DB_HOST' backend/.env | cut -d= -f2):$(grep '^DB_PORT' backend/.env | cut -d= -f2)/$(grep '^DB_DATABASE' backend/.env | cut -d= -f2))" || fail "DB_CONNECTION bukan mysql di backend/.env"
php -m 2>/dev/null | grep -qi 'pdo_mysql' && ok "ekstensi pdo_mysql aktif" || fail "ekstensi pdo_mysql tidak aktif"
[ -d backend/vendor/dompdf/dompdf ] && ok "dompdf terpasang" || fail "dompdf belum terpasang (jalankan: cd backend && composer require dompdf/dompdf)"

section "1. Lint PHP"
LINT_ERR=0
while IFS= read -r f; do
  out=$(php -l "$f" 2>&1) || { LINT_ERR=$((LINT_ERR + 1)); say "  $out"; }
done < <(find backend/app backend/routes backend/database backend/config backend/bootstrap backend/resources backend/tests -name '*.php' 2>/dev/null)
[ "$LINT_ERR" -eq 0 ] && ok "semua berkas PHP lolos lint" || fail "$LINT_ERR berkas PHP bermasalah"

section "2. Rute Laravel"
( cd backend && php artisan route:list --path=api >> "$LOG" 2>&1 ) && ok "route:list berhasil (semua controller termuat)" || fail "route:list gagal (lihat verify.log)"

section "3. Migrasi + seeder (MySQL)"
( cd backend && php artisan migrate:fresh --seed --force >> "$LOG" 2>&1 ) && ok "migrate:fresh --seed berhasil" || { fail "migrasi/seeder gagal (lihat verify.log)"; say "\nBerhenti: uji API butuh database."; exit 1; }

section "4. Uji API (server uji di port $PORT)"
( cd backend && php artisan serve --host=127.0.0.1 --port=$PORT >> "$LOG" 2>&1 ) &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null; wait $SERVER_PID 2>/dev/null' EXIT
UP=0
for i in $(seq 1 30); do
  if curl -s -o /dev/null "http://127.0.0.1:$PORT/up"; then UP=1; break; fi
  sleep 1
done
if [ "$UP" -eq 1 ]; then
  ok "server uji menyala"
  ( cd backend && php tests/smoke.php "http://127.0.0.1:$PORT/api" 2>&1 | tee -a "$LOG" )
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then fail "ada uji API yang gagal (lihat daftar di atas)"; else ok "semua uji API lolos"; fi
else
  fail "server uji tidak menyala"
fi
kill $SERVER_PID 2>/dev/null; wait $SERVER_PID 2>/dev/null; trap - EXIT

section "5. Memulihkan data demo"
( cd backend && php artisan migrate:fresh --seed --force >> "$LOG" 2>&1 ) && ok "data demo dipulihkan" || fail "gagal memulihkan data demo"

if command -v flutter >/dev/null 2>&1 && [ -d frontend/web ]; then
  section "6. Flutter analyze"
  ( cd frontend && flutter pub get >> "$LOG" 2>&1 )
  ( cd frontend && flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tee -a "$LOG" ) && ok "flutter analyze tanpa error" || fail "flutter analyze menemukan error (lihat verify.log)"
  if [ "$1" = "--build" ]; then
    section "7. Flutter build web"
    ( cd frontend && flutter build web --release >> "$LOG" 2>&1 ) && ok "flutter build web berhasil" || fail "flutter build web gagal (lihat verify.log)"
  fi
else
  say "\n(Langkah Flutter dilewati: jalankan ./setup.sh frontend lebih dulu.)"
fi

section "RINGKASAN"
if [ "$FAILS" -eq 0 ]; then
  say "SEMUA LOLOS. Aplikasi siap dipakai: ./run.sh"
else
  say "$FAILS langkah gagal. Kirim isi $LOG ke Claude untuk diperbaiki."
fi
exit $FAILS
