<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Report extends Model
{
    protected $guarded = [];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function unit()
    {
        return $this->belongsTo(Unit::class);
    }

    public function facility()
    {
        return $this->belongsTo(Facility::class);
    }

    public function updates()
    {
        return $this->hasMany(ReportUpdate::class);
    }
}
