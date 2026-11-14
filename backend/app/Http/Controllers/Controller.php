<?php

namespace App\Http\Controllers;

use App\Models\Apartment;
use App\Models\ApartmentMember;
use Illuminate\Http\Request;

abstract class Controller
{
    protected array $staff = ['owner', 'admin'];

    protected function ctx(Request $r, $aid, array $roles = []): ApartmentMember
    {
        $m = ApartmentMember::where('apartment_id', $aid)->where('user_id', $r->user()->id)->where('is_active', true)->first();
        if (! $m || ($roles && ! in_array($m->role, $roles))) {
            abort(403, 'Anda tidak memiliki akses ke data ini.');
        }

        return $m;
    }

    protected function apt($aid): Apartment
    {
        return Apartment::findOrFail($aid);
    }

    protected function module(Apartment $a, string $key): void
    {
        if (! in_array($key, $a->modules ?? [])) {
            abort(403, 'Fitur ini tidak diaktifkan di apartemen ini.');
        }
    }

    protected function staffIds($aid): array
    {
        return ApartmentMember::where('apartment_id', $aid)->whereIn('role', $this->staff)->where('is_active', true)->pluck('user_id')->all();
    }

    protected function tenantIds($aid): array
    {
        return ApartmentMember::where('apartment_id', $aid)->where('role', 'tenant')->where('is_active', true)->pluck('user_id')->all();
    }
}
