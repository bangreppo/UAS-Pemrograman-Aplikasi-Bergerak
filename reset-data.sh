#!/usr/bin/env bash
# Mengembalikan database ke data demo awal (semua perubahan hilang).
cd "$(dirname "$0")/backend"
XAMPP_BIN=/Applications/XAMPP/xamppfiles/bin
if ! command -v php >/dev/null 2>&1 && [ -x "$XAMPP_BIN/php" ]; then export PATH="$XAMPP_BIN:$PATH"; fi
php artisan migrate:fresh --seed --force && echo "Data demo dipulihkan."
