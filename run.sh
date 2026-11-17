#!/usr/bin/env bash
# MyHously - jalankan backend, scheduler, dan aplikasi (Chrome) sekaligus. Tekan Ctrl+C untuk berhenti.
cd "$(dirname "$0")"
XAMPP_BIN=/Applications/XAMPP/xamppfiles/bin
if ! command -v php >/dev/null 2>&1 && [ -x "$XAMPP_BIN/php" ]; then export PATH="$XAMPP_BIN:$PATH"; fi
[ -f backend/artisan ] || { echo "Jalankan ./setup.sh dulu."; exit 1; }

( cd backend && php artisan serve --host=127.0.0.1 --port=8000 ) &
BPID=$!
( cd backend && php artisan schedule:work >/dev/null 2>&1 ) &
SPID=$!
trap 'kill $BPID $SPID 2>/dev/null; exit 0' INT TERM EXIT
sleep 2
echo "Backend: http://127.0.0.1:8000  |  Akun demo: owner@myhously.test / password"
cd frontend && flutter run -d chrome
