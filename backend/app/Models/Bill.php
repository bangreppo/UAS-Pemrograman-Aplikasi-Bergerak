<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Bill extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'period' => 'date:Y-m-d',
            'issued_on' => 'date:Y-m-d',
            'payable_from' => 'date:Y-m-d',
            'due_date' => 'date:Y-m-d',
            'paid_at' => 'datetime',
        ];
    }

    public function items()
    {
        return $this->hasMany(BillItem::class);
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
