<?php

namespace App\Console\Commands;

use App\Support\Demo;

use App\Models\Apartment;
use App\Services\BillingService;
use Carbon\Carbon;
use Illuminate\Console\Command;

class GenerateBills extends Command
{
    protected $signature = 'myhously:generate-bills {--date= : Tanggal simulasi (YYYY-MM-DD)}';

    protected $description = 'Terbitkan tagihan sewa (tanggal terbit) dan tagihan layanan tambahan (akhir bulan)';

    public function handle(BillingService $svc): int
    {
        $today = $this->option('date') ? Carbon::parse($this->option('date'))->startOfDay() : Demo::now()->startOfDay();
        foreach (Apartment::all() as $a) {
            if ($today->day === min((int) $a->rent_issue_day, $today->daysInMonth)) {
                $n = $svc->issueRent($a, $today->copy()->addMonthNoOverflow()->startOfMonth(), $today);
                $this->info("{$a->name}: {$n} tagihan sewa diterbitkan.");
            }
            if ($today->day === $today->daysInMonth) {
                $n = $svc->issueExtras($a, $today->copy()->startOfMonth(), $today);
                $this->info("{$a->name}: {$n} tagihan layanan tambahan diterbitkan.");
            }
        }

        return self::SUCCESS;
    }
}
