<?php

namespace App\Support;

use Carbon\Carbon;
use Illuminate\Support\Facades\Cache;

/** Jam aplikasi yang bisa digeser untuk demo/uji coba alur bulanan. */
class Demo
{
    public static function offset(): int
    {
        return (int) Cache::get('demo_offset_days', 0);
    }

    public static function setOffset(int $days): void
    {
        if ($days === 0) {
            Cache::forget('demo_offset_days');
        } else {
            Cache::forever('demo_offset_days', $days);
        }
    }

    public static function now(): Carbon
    {
        return now()->addDays(self::offset());
    }

    public static function today(): Carbon
    {
        return self::now()->startOfDay();
    }

    public static function enabled(): bool
    {
        return (bool) config('demo.enabled', true);
    }
}
