<?php

namespace App\Http\Controllers;

use App\Support\Demo;

use App\Support\Media;

use App\Models\ReportPhoto;

use App\Models\Announcement;
use App\Models\AppNotification;
use App\Models\Facility;
use App\Models\Occupancy;
use App\Models\Report;
use App\Models\ReportUpdate;
use App\Services\Notify;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CommunityController extends Controller
{
    // ---------- Pengumuman ----------
    public function announcements(Request $r, $aid)
    {
        $this->ctx($r, $aid);
        $this->module($this->apt($aid), 'announcements');

        return Announcement::with('user:id,name')->where('apartment_id', $aid)->orderByDesc('is_pinned')->orderByDesc('created_at')->limit(100)->get();
    }

    protected function announcementRules(): array
    {
        return ['title' => 'required|string|max:150', 'body' => 'required|string', 'category' => 'nullable|in:info,penting,pembayaran,perawatan', 'is_pinned' => 'nullable|boolean'];
    }

    public function storeAnnouncement(Request $r, $aid)
    {
        $this->ctx($r, $aid, $this->staff);
        $this->module($this->apt($aid), 'announcements');
        $d = $r->validate($this->announcementRules());
        $an = Announcement::create($d + ['apartment_id' => $aid, 'user_id' => $r->user()->id]);
        Notify::to($this->tenantIds($aid), (int) $aid, 'Pengumuman baru', $an->title, 'announcement');

        return response()->json($an, 201);
    }

    public function updateAnnouncement(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $an = Announcement::where('apartment_id', $aid)->findOrFail($id);
        $an->update($r->validate($this->announcementRules()));

        return $an->fresh();
    }

    public function destroyAnnouncement(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        Announcement::where('apartment_id', $aid)->findOrFail($id)->delete();

        return ['message' => 'Pengumuman dihapus.'];
    }

    // ---------- Fasilitas bersama ----------
    public function facilities(Request $r, $aid)
    {
        $this->ctx($r, $aid);
        $this->module($this->apt($aid), 'facilities');

        return Facility::where('apartment_id', $aid)->orderBy('name')->get();
    }

    protected function facilityRules(): array
    {
        return [
            'name' => 'required|string|max:100', 'description' => 'nullable|string', 'location' => 'nullable|string|max:150',
            'hours' => 'nullable|string|max:100', 'rules' => 'nullable|string', 'status' => 'required|in:available,closed,maintenance',
        ];
    }

    public function storeFacility(Request $r, $aid)
    {
        $this->ctx($r, $aid, $this->staff);
        $this->module($this->apt($aid), 'facilities');

        return response()->json(Facility::create($r->validate($this->facilityRules()) + ['apartment_id' => $aid]), 201);
    }

    public function updateFacility(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $f = Facility::where('apartment_id', $aid)->findOrFail($id);
        $f->update($r->validate($this->facilityRules()));

        return $f->fresh();
    }

    public function destroyFacility(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $f = Facility::where('apartment_id', $aid)->findOrFail($id);
        if (Report::where('facility_id', $f->id)->exists()) {
            abort(422, 'Fasilitas memiliki riwayat laporan. Ubah statusnya menjadi ditutup sementara.');
        }
        $f->delete();

        return ['message' => 'Fasilitas dihapus.'];
    }

    // ---------- Laporan kerusakan ----------
    public function reports(Request $r, $aid)
    {
        $m = $this->ctx($r, $aid);
        $this->module($this->apt($aid), 'reports');
        $q = Report::with(['user:id,name', 'unit:id,number', 'facility:id,name'])->where('apartment_id', $aid);
        if ($m->role === 'tenant') {
            $q->where('user_id', $r->user()->id);
        }
        if ($r->query('status')) {
            $q->where('status', $r->query('status'));
        }

        return $q->orderByDesc('updated_at')->limit(200)->get();
    }

    public function storeReport(Request $r, $aid)
    {
        $this->ctx($r, $aid, ['tenant']);
        $this->module($this->apt($aid), 'reports');
        $d = $r->validate(['title' => 'required|string|max:150', 'description' => 'required|string', 'facility_id' => 'nullable|integer', 'photos' => 'nullable|array|max:3', 'photos.*' => 'image|max:4096']);
        $files = $r->file('photos', []);
        $uid = $r->user()->id;
        $unitId = null;
        if (! empty($d['facility_id'])) {
            Facility::where('apartment_id', $aid)->findOrFail($d['facility_id']);
        } else {
            $o = Occupancy::where('apartment_id', $aid)->where('user_id', $uid)->where('status', 'active')->first();
            $unitId = $o?->unit_id;
        }
        $rep = DB::transaction(function () use ($d, $aid, $uid, $unitId, $files) {
            $rep = Report::create(['apartment_id' => $aid, 'user_id' => $uid, 'unit_id' => $unitId, 'facility_id' => $d['facility_id'] ?? null, 'title' => $d['title'], 'description' => $d['description'], 'status' => 'menunggu']);
            ReportUpdate::create(['report_id' => $rep->id, 'user_id' => $uid, 'status' => 'menunggu', 'note' => 'Laporan dikirim.']);
            foreach ($files as $f) {
                ReportPhoto::create(['report_id' => $rep->id, 'path' => Media::store($f, 'reports')]);
            }

            return $rep;
        });
        Notify::to($this->staffIds($aid), (int) $aid, 'Laporan baru', $rep->title, 'report');

        return response()->json($rep, 201);
    }

    public function report(Request $r, $aid, $id)
    {
        $m = $this->ctx($r, $aid);
        $rep = Report::with(['user:id,name', 'unit:id,number', 'facility:id,name', 'updates.user:id,name', 'photos'])->where('apartment_id', $aid)->findOrFail($id);
        if ($m->role === 'tenant' && $rep->user_id !== $r->user()->id) {
            abort(403, 'Anda tidak memiliki akses ke data ini.');
        }

        return $rep;
    }

    public function reportStatus(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $d = $r->validate(['status' => 'required|in:diterima,ditolak,ditangani,selesai', 'note' => 'nullable|string|max:500']);
        $rep = Report::where('apartment_id', $aid)->findOrFail($id);
        $flow = ['menunggu' => ['diterima', 'ditolak'], 'diterima' => ['ditangani', 'selesai'], 'ditangani' => ['selesai']];
        if (! in_array($d['status'], $flow[$rep->status] ?? [])) {
            abort(422, 'Status tidak dapat diubah dari "'.$rep->status.'" menjadi "'.$d['status'].'".');
        }
        if ($d['status'] === 'ditolak' && empty($d['note'])) {
            abort(422, 'Alasan penolakan wajib diisi.');
        }
        DB::transaction(function () use ($rep, $d, $r) {
            $rep->update(['status' => $d['status'], 'reject_reason' => $d['status'] === 'ditolak' ? $d['note'] : $rep->reject_reason]);
            ReportUpdate::create(['report_id' => $rep->id, 'user_id' => $r->user()->id, 'status' => $d['status'], 'note' => $d['note'] ?? null]);
        });
        Notify::to([$rep->user_id], (int) $aid, 'Laporan diperbarui', '"'.$rep->title.'" kini berstatus '.$d['status'].'.', 'report');

        return $this->report($r, $aid, $id);
    }

    public function facilityPhoto(Request $r, $aid, $id)
    {
        $this->ctx($r, $aid, $this->staff);
        $r->validate(['photo' => 'required|image|max:4096']);
        $f = Facility::where('apartment_id', $aid)->findOrFail($id);
        $old = $f->photo_path;
        $f->update(['photo_path' => Media::store($r->file('photo'), 'facilities')]);
        Media::delete($old);

        return $f->fresh();
    }

    // ---------- Notifikasi ----------
    public function unread(Request $r)
    {
        $q = AppNotification::where('user_id', $r->user()->id)->whereNull('read_at');
        $latest = (clone $q)->orderByDesc('id')->first(['id', 'title']);

        return ['count' => (clone $q)->count(), 'latest' => $latest];
    }

    public function notifications(Request $r)
    {
        $q = AppNotification::where('user_id', $r->user()->id);
        if ($r->query('apartment_id')) {
            $q->where(fn ($w) => $w->where('apartment_id', $r->query('apartment_id'))->orWhereNull('apartment_id'));
        }

        return $q->orderByDesc('id')->limit(100)->get();
    }

    public function readAll(Request $r)
    {
        AppNotification::where('user_id', $r->user()->id)->whereNull('read_at')->update(['read_at' => Demo::now()]);

        return ['message' => 'Semua notifikasi ditandai dibaca.'];
    }

    public function readOne(Request $r, $id)
    {
        AppNotification::where('user_id', $r->user()->id)->where('id', $id)->update(['read_at' => Demo::now()]);

        return ['message' => 'Ditandai dibaca.'];
    }
}
