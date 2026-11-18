<?php

namespace App\Http\Controllers;

use App\Support\Media;

use App\Models\AppNotification;
use App\Models\ApartmentMember;
use App\Models\JoinRequest;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $r)
    {
        $d = $r->validate([
            'name' => 'required|string|max:100',
            'email' => 'required|email|max:150|unique:users,email',
            'phone' => 'required|string|max:30',
            'password' => 'required|string|min:6|max:100',
        ], [
            'email.unique' => 'Email sudah terdaftar. Silakan masuk.',
            'password.min' => 'Kata sandi minimal 6 karakter.',
        ]);
        $u = User::create($d);

        return response()->json(['token' => $u->createToken('app')->plainTextToken, 'user' => $u], 201);
    }

    public function login(Request $r)
    {
        $d = $r->validate(['email' => 'required|email', 'password' => 'required|string']);
        $u = User::where('email', $d['email'])->first();
        if (! $u || ! Hash::check($d['password'], $u->password)) {
            throw ValidationException::withMessages(['email' => 'Email atau kata sandi salah.']);
        }

        return ['token' => $u->createToken('app')->plainTextToken, 'user' => $u];
    }

    public function me(Request $r)
    {
        $u = $r->user();
        $memberships = ApartmentMember::with('apartment:id,name,address,city')->where('user_id', $u->id)->where('is_active', true)->orderBy('id')->get()
            ->map(fn ($m) => ['apartment_id' => $m->apartment_id, 'role' => $m->role, 'apartment' => $m->apartment])->values();
        $requests = JoinRequest::with(['apartment:id,name', 'unit:id,number'])->where('user_id', $u->id)->orderByDesc('id')->limit(10)->get();

        return [
            'user' => $u,
            'memberships' => $memberships,
            'requests' => $requests,
            'admin_invites' => ApartmentMember::with('apartment:id,name,address')->where('user_id', $u->id)->where('invite_status', 'pending')->get()
                ->map(fn ($m) => ['id' => $m->id, 'apartment' => $m->apartment])->values(),
            'unread' => AppNotification::where('user_id', $u->id)->whereNull('read_at')->count(),
        ];
    }

    public function update(Request $r)
    {
        $u = $r->user();
        $d = $r->validate([
            'name' => 'sometimes|required|string|max:100',
            'phone' => 'sometimes|required|string|max:30',
            'gender' => 'nullable|in:L,P',
            'hometown' => 'nullable|string|max:80',
            'emergency_name' => 'nullable|string|max:100',
            'emergency_phone' => 'nullable|string|max:30',
            'current_password' => 'nullable|string',
            'password' => 'nullable|string|min:6|max:100',
        ]);
        if (! empty($d['password'])) {
            if (! Hash::check($d['current_password'] ?? '', $u->password)) {
                throw ValidationException::withMessages(['current_password' => 'Kata sandi saat ini tidak sesuai.']);
            }
            $u->password = $d['password'];
        }
        $u->fill(array_intersect_key($d, array_flip(['name', 'phone', 'gender', 'hometown', 'emergency_name', 'emergency_phone'])))->save();

        return $u;
    }

    public function photo(Request $r)
    {
        $r->validate(['photo' => 'required|image|max:4096']);
        $u = $r->user();
        $old = $u->photo_path;
        $u->photo_path = Media::store($r->file('photo'), 'profiles');
        $u->save();
        Media::delete($old);

        return $u->fresh();
    }

    public function removePhoto(Request $r)
    {
        $u = $r->user();
        Media::delete($u->photo_path);
        $u->photo_path = null;
        $u->save();

        return $u->fresh();
    }

    public function logout(Request $r)
    {
        $r->user()->currentAccessToken()->delete();

        return ['message' => 'Berhasil keluar.'];
    }
}
