<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MoveOutRequest extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'desired_date' => 'date:Y-m-d',
        ];
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
