#!/usr/bin/env bash
# MyHously - skrip setup satu kali jalan (macOS / Linux)
# Pemakaian:  ./setup.sh            -> backend + frontend
#             ./setup.sh backend    -> hanya backend
#             ./setup.sh frontend   -> hanya frontend
set -e
cd "$(dirname "$0")"

# ===== Konfigurasi database (ubah bila perlu) =====
DB_HOST=127.0.0.1
DB_PORT=3307        # XAMPP kamu memakai port 3307
DB_NAME=myhously
DB_USER=root
DB_PASS=
# ==================================================

TARGET="${1:-all}"

# Cari php dan mysql (termasuk bawaan XAMPP di macOS)
XAMPP_BIN=/Applications/XAMPP/xamppfiles/bin
if ! command -v php >/dev/null 2>&1 && [ -x "$XAMPP_BIN/php" ]; then export PATH="$XAMPP_BIN:$PATH"; fi
MYSQL_BIN="$(command -v mysql || true)"
if [ -z "$MYSQL_BIN" ] && [ -x "$XAMPP_BIN/mysql" ]; then MYSQL_BIN="$XAMPP_BIN/mysql"; fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' tidak ditemukan. $2"; exit 1; }; }

setup_backend() {
  need php "Pasang PHP 8.2+ (atau jalankan XAMPP)."
  need composer "Pasang Composer dari https://getcomposer.org"
  echo "==> [Backend] Menyiapkan Laravel..."

  if [ ! -f backend/artisan ]; then
    rm -rf .laravel_tmp
    composer create-project laravel/laravel .laravel_tmp --no-interaction
    ( cd .laravel_tmp && php artisan install:api --no-interaction || true )
    if ! ls .laravel_tmp/database/migrations 2>/dev/null | grep -q personal_access_tokens; then
      ( cd .laravel_tmp && php artisan vendor:publish --provider="Laravel\\Sanctum\\SanctumServiceProvider" --force )
    fi
    echo "==> [Backend] Memasang dompdf (PDF)..."
    ( cd .laravel_tmp && composer require dompdf/dompdf --no-interaction )
    echo "==> [Backend] Menyalin kode MyHously ke proyek Laravel..."
    cp -R backend/. .laravel_tmp/
    rm -rf backend
    mv .laravel_tmp backend
  else
    echo "    Proyek Laravel sudah ada, melewati pembuatan."
    ( cd backend && { [ -d vendor/dompdf/dompdf ] || composer require dompdf/dompdf --no-interaction; } )
  fi

  cd backend
  # Konfigurasi .env
  [ -f .env ] || cp .env.example .env
  perl -ni -e 'print unless /^#?\s*(DB_CONNECTION|DB_HOST|DB_PORT|DB_DATABASE|DB_USERNAME|DB_PASSWORD|APP_TIMEZONE|APP_NAME|APP_URL|CACHE_STORE|SESSION_DRIVER|DEMO_MODE)=/' .env
  cat >> .env <<ENVEOF

APP_NAME=MyHously
APP_URL=http://127.0.0.1:8000
APP_TIMEZONE=Asia/Jakarta
DEMO_MODE=true
CACHE_STORE=file
SESSION_DRIVER=file
DB_CONNECTION=mysql
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS
ENVEOF
  grep -q '^APP_KEY=base64' .env || php artisan key:generate --force

  # Buat database bila klien mysql tersedia
  if [ -n "$MYSQL_BIN" ]; then
    if [ -n "$DB_PASS" ]; then PASSARG="-p$DB_PASS"; else PASSARG=""; fi
    "$MYSQL_BIN" -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" $PASSARG -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
      && echo "    Database '$DB_NAME' siap." \
      || echo "    PERINGATAN: gagal membuat database otomatis. Buat database '$DB_NAME' lewat phpMyAdmin lalu jalankan ulang ./setup.sh backend"
  else
    echo "    PERINGATAN: klien mysql tidak ditemukan. Pastikan database '$DB_NAME' sudah ada (phpMyAdmin)."
  fi

  php artisan config:publish cors --no-interaction >/dev/null 2>&1 || true
  php artisan config:clear >/dev/null 2>&1 || true
  echo "==> [Backend] Migrasi dan data demo..."
  php artisan migrate:fresh --seed --force
  cd ..
  echo "==> [Backend] Selesai. Jalankan:  cd backend && php artisan serve"
}

patch_android() {
  M=android/app/src/main/AndroidManifest.xml
  [ -f "$M" ] || return 0
  grep -q 'usesCleartextTraffic' "$M" || perl -pi -e 's/<application/<application android:usesCleartextTraffic="true"/' "$M"
  grep -q 'android.permission.INTERNET' "$M" || perl -pi -e 's#(<manifest[^>]*>)#$1\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$M"
  grep -q '<queries>' "$M" || perl -0pi -e 's#</manifest>#    <queries>\n        <intent>\n            <action android:name="android.intent.action.VIEW"/>\n            <data android:scheme="https"/>\n        </intent>\n        <intent>\n            <action android:name="android.intent.action.VIEW"/>\n            <data android:scheme="http"/>\n        </intent>\n    </queries>\n</manifest>#' "$M"
}

setup_frontend() {
  need flutter "Pasang Flutter SDK dari https://docs.flutter.dev/get-started/install"
  echo "==> [Frontend] Menyiapkan Flutter..."
  cd frontend
  if [ ! -d web ] || [ ! -d android ]; then
    rm -rf ../.fe_backup && mkdir -p ../.fe_backup
    cp -R lib pubspec.yaml ../.fe_backup/
    flutter create . --platforms=web,android --project-name myhously --org id.myhously
    rm -rf lib && cp -R ../.fe_backup/lib lib
    cp ../.fe_backup/pubspec.yaml pubspec.yaml
    rm -rf test ../.fe_backup
  fi
  patch_android
  flutter pub get
  cd ..
  echo "==> [Frontend] Selesai. Jalankan:  cd frontend && flutter run -d chrome"
}

case "$TARGET" in
  backend) setup_backend ;;
  frontend) setup_frontend ;;
  all) setup_backend; setup_frontend ;;
  *) echo "Argumen tidak dikenal: $TARGET (gunakan: backend | frontend)"; exit 1 ;;
esac

echo
echo "SELESAI. Langkah berikutnya:"
echo "  1) Terminal A:  cd backend && php artisan serve"
echo "  2) Terminal B:  cd frontend && flutter run -d chrome"
echo "  Akun demo: owner@myhously.test / password"
