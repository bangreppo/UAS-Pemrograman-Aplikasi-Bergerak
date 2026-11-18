<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Apartment extends Model
{
    protected $guarded = [];

    protected $hidden = ['photo_path'];

    protected $appends = ['photo_url'];

    public function getPhotoUrlAttribute(): ?string
    {
        return \App\Support\Media::url($this->photo_path);
    }

    protected function casts(): array
    {
        return [
            'modules' => 'array',
        ];
    }

    public function members()
    {
        return $this->hasMany(ApartmentMember::class);
    }

    public function unitTypes()
    {
        return $this->hasMany(UnitType::class);
    }

    public function units()
    {
        return $this->hasMany(Unit::class);
    }
}
