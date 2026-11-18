<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UnitType extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'features' => 'array',
        ];
    }

    public function units()
    {
        return $this->hasMany(Unit::class);
    }
}
