<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ServiceSubscription extends Model
{
    protected $guarded = [];

    public function occupancy()
    {
        return $this->belongsTo(Occupancy::class);
    }

    public function service()
    {
        return $this->belongsTo(Service::class);
    }
}
