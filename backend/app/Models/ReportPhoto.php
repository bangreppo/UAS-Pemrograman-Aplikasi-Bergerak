<?php

namespace App\Models;

use App\Support\Media;
use Illuminate\Database\Eloquent\Model;

class ReportPhoto extends Model
{
    protected $guarded = [];

    protected $hidden = ['path'];

    protected $appends = ['url'];

    public function getUrlAttribute(): ?string
    {
        return Media::url($this->path);
    }
}
