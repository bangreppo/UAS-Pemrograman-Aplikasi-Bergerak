<?php

namespace App\Support;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class Media
{
    public static function store(UploadedFile $file, string $dir): string
    {
        $ext = $file->extension() ?: 'jpg';

        return $file->storeAs($dir, Str::random(40).'.'.$ext, 'public');
    }

    public static function delete(?string $path): void
    {
        if ($path) {
            Storage::disk('public')->delete($path);
        }
    }

    public static function url(?string $path): ?string
    {
        return $path ? url('/api/media/'.$path) : null;
    }
}
