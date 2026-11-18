<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Unit extends Model
{
    protected $guarded = [];

    public function type()
    {
        return $this->belongsTo(UnitType::class, 'unit_type_id');
    }

    public function occupancies()
    {
        return $this->hasMany(Occupancy::class);
    }
}
