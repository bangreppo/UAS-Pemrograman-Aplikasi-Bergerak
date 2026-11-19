<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\Storage;

class MediaController extends Controller
{
    public function show(string $dir, string $file)
    {
        abort_unless(in_array($dir, ['reports', 'profiles', 'apartments', 'facilities']), 404);
        $path = $dir.'/'.$file;
        abort_unless(Storage::disk('public')->exists($path), 404);

        return Storage::disk('public')->response($path, null, ['Cache-Control' => 'public, max-age=86400']);
    }
}
