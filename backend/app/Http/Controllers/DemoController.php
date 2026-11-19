<?php

namespace App\Http\Controllers;

use App\Models\Apartment;
use App\Models\ApartmentMember;
use App\Services\BillingService;
use App\Support\Demo;
use Illuminate\Http\Request;

class DemoController extends Controller
{
    public function show()
    {
        return $this->demoInfo();
    }

    public function shift(Request $r)
    {
        abort_unless(Demo::enabled(), 403, 'Mode demo tidak aktif.');
        $isStaff = ApartmentMember::where('user_id', $r->user()->id)->whereIn('role', $this->staff)->where('is_active', true)->exists();
        abort_unless($isStaff, 403, 'Hanya pengelola yang dapat mengatur waktu demo.');
        $d = $r->validate(['days' => 'nullable|integer|min:-366|max:60', 'reset' => 'nullable|boolean']);

        if ($r->boolean('reset')) {
            Demo::setOffset(0);

            return ['message' => 'Waktu aplikasi dikembalikan ke waktu nyata.', 'demo' => $this->demoInfo()];
        }
        $days = (int) ($d['days'] ?? 0);
        if ($days <= 0) {
            Demo::setOffset(Demo::offset() + $days);

            return ['message' => 'Waktu dimundurkan. Tagihan dan denda yang sudah terbentuk tidak dibatalkan.', 'demo' => $this->demoInfo()];
        }
        $svc = new BillingService();
        $tot = ['rent' => 0, 'extras' => 0, 'fines' => 0, 'reminders' => 0];
        for ($i = 0; $i < $days; $i++) {
            Demo::setOffset(Demo::offset() + 1);
            $today = Demo::today();
            foreach (Apartment::all() as $a) {
                foreach ($svc->runDaily($a, $today) as $k => $v) {
                    $tot[$k] += $v;
                }
            }
        }

        return [
            'message' => 'Waktu maju '.$days.' hari ke '.Demo::today()->format('d/m/Y').'. Terbit: '.$tot['rent'].' tagihan sewa, '.$tot['extras'].' tagihan layanan, '.$tot['reminders'].' pengingat, '.$tot['fines'].' denda baru.',
            'demo' => $this->demoInfo(),
        ];
    }
}
