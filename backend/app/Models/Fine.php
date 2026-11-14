<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Fine extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'started_on' => 'date:Y-m-d',
            'is_adjusted' => 'boolean',
            'paid_at' => 'datetime',
        ];
    }

    public function unit()
    {
        return $this->belongsTo(Unit::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function occupancy()
    {
        return $this->belongsTo(Occupancy::class);
    }
}
