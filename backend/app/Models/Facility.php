<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Facility extends Model
{
    protected $guarded = [];

    protected $hidden = ['photo_path'];

    protected $appends = ['photo_url'];

    public function getPhotoUrlAttribute(): ?string
    {
        return \App\Support\Media::url($this->photo_path);
    }
}
