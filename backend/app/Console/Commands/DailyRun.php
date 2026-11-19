<?php

namespace App\Console\Commands;

use App\Models\Apartment;
use App\Services\BillingService;
use App\Support\Demo;
use Carbon\Carbon;
use Illuminate\Console\Command;

class DailyRun extends Command
{
    protected $signature = 'myhously:daily {--date= : Tanggal simulasi (YYYY-MM-DD)}';

    protected $description = 'Rutinitas harian: tagihan sewa, tagihan layanan, pengingat jatuh tempo, dan denda';

    public function handle(BillingService $svc): int
    {
        $today = $this->option('date') ? Carbon::parse($this->option('date'))->startOfDay() : Demo::today();
        foreach (Apartment::all() as $a) {
            $r = $svc->runDaily($a, $today);
            $this->info("{$a->name} ({$today->toDateString()}): sewa {$r['rent']}, layanan {$r['extras']}, pengingat {$r['reminders']}, denda baru {$r['fines']}");
        }

        return self::SUCCESS;
    }
}
