<?php

namespace App\Console\Commands;

use App\Models\Apartment;
use App\Services\BillingService;
use Carbon\Carbon;
use Illuminate\Console\Command;

class CalculateFines extends Command
{
    protected $signature = 'myhously:calc-fines {--date= : Tanggal simulasi (YYYY-MM-DD)}';

    protected $description = 'Hitung denda keterlambatan harian (per unit)';

    public function handle(BillingService $svc): int
    {
        $today = $this->option('date') ? Carbon::parse($this->option('date'))->startOfDay() : now()->startOfDay();
        foreach (Apartment::all() as $a) {
            $n = $svc->calcFines($a, $today);
            $this->info("{$a->name}: {$n} denda baru.");
        }

        return self::SUCCESS;
    }
}
