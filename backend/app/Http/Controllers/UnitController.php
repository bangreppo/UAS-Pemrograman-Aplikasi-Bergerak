<?php

namespace App\Http\Controllers;

use App\Models\Bill;
use App\Models\Occupancy;
use App\Models\Unit;
use App\Models\UnitType;
use Illuminate\Http\Request;

class UnitController extends Controller
{
    public function types(Request $r, $aid)
    {
        $this->ctx($r, $aid);

        return UnitType::where('apartment_id', $aid)->withCount('units')->orderBy('rent_price')->get();
    }

    protected function typeRules(): array
    {
        return [
            'name' => 'required|string|max:60',
            'rent_price' => 'required|integer|min:0',
            'capacity' => 'nullable|integer|min:1|max:6',
            'area' => 'nullable|numeric|min:0',
            'bedrooms' => 'nullable|integer|min:0|max:10',
            'bathrooms' => 'nullable|integer|min:0|max:10',
            'features' => 'nullable|array',
        ];
    }

    public function storeType(Request $r, $aid)
    {
        $this->ctx($r, $aid, ['owner']);
        $d = $r->validate($this->typeRules());
        $t = UnitType::create(array_filter($d, fn ($v) => $v !== null) + ['apartment_id' => $aid]);

        return response()->json($t, 201);
    }

    public function updateType(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, ['owner']);
        $t = UnitType::where('apartment_id', $aid)->findOrFail($id);
        $t->update($r->validate($this->typeRules()));

        return $t->fresh();
    }

    public function destroyType(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, ['owner']);
        $t = UnitType::where('apartment_id', $aid)->findOrFail($id);
        if (Unit::where('unit_type_id', $t->id)->exists()) {
            abort(422, 'Tipe unit masih dipakai oleh unit. Pindahkan atau hapus unit terlebih dahulu.');
        }
        $t->delete();

        return ['message' => 'Tipe unit dihapus.'];
    }

    public function units(Request $r, $aid)
    {
        $this->ctx($r, $aid);
        $q = Unit::with([
            'type:id,name,rent_price,capacity,features,area,bedrooms,bathrooms',
            'occupancies' => fn ($q) => $q->where('status', 'active')->orderByDesc('is_primary')->with('user:id,name,phone'),
        ])->where('apartment_id', $aid);
        if ($r->query('status')) {
            $q->where('status', $r->query('status'));
        }

        return $q->orderBy('floor')->orderBy('number')->get();
    }

    public function storeUnit(Request $r, $aid)
    {
        $this->ctx($r, $aid, $this->staff);
        $d = $r->validate([
            'number' => 'required|string|max:20',
            'floor' => 'required|integer|min:0|max:200',
            'unit_type_id' => 'required|integer',
            'status' => 'nullable|in:available,maintenance',
        ]);
        UnitType::where('apartment_id', $aid)->findOrFail($d['unit_type_id']);
        if (Unit::where('apartment_id', $aid)->where('number', $d['number'])->exists()) {
            abort(422, 'Nomor unit sudah digunakan.');
        }
        $u = Unit::create($d + ['apartment_id' => $aid, 'status' => $d['status'] ?? 'available']);

        return response()->json($u->load('type'), 201);
    }

    public function updateUnit(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $u = Unit::where('apartment_id', $aid)->findOrFail($id);
        $d = $r->validate([
            'number' => 'sometimes|required|string|max:20',
            'floor' => 'sometimes|required|integer|min:0|max:200',
            'unit_type_id' => 'sometimes|required|integer',
            'status' => 'sometimes|in:available,maintenance',
        ]);
        if (isset($d['unit_type_id'])) {
            UnitType::where('apartment_id', $aid)->findOrFail($d['unit_type_id']);
        }
        if (isset($d['number']) && Unit::where('apartment_id', $aid)->where('number', $d['number'])->where('id', '!=', $u->id)->exists()) {
            abort(422, 'Nomor unit sudah digunakan.');
        }
        $active = Occupancy::where('unit_id', $u->id)->where('status', 'active')->exists();
        if (isset($d['status']) && $active) {
            abort(422, 'Unit masih dihuni. Akhiri masa tinggal penghuni terlebih dahulu untuk mengubah status.');
        }
        $u->update($d);

        return $u->fresh()->load('type');
    }

    public function destroyUnit(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $u = Unit::where('apartment_id', $aid)->findOrFail($id);
        if (Occupancy::where('unit_id', $u->id)->exists() || Bill::where('unit_id', $u->id)->exists()) {
            abort(422, 'Unit memiliki riwayat penghuni atau tagihan sehingga tidak dapat dihapus. Ubah statusnya menjadi tidak tersedia.');
        }
        $u->delete();

        return ['message' => 'Unit dihapus.'];
    }
}
