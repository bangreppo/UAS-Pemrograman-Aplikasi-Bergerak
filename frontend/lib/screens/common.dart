import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../ui.dart';
import 'apartments.dart';

// ---------------------------------------------------------------- Bukti pembayaran
Future<void> showReceipt(BuildContext c, int aptId, int id) async {
  final p = await guard(c, () => Api.get('/apartments/$aptId/payments/$id'));
  if (p == null || !c.mounted) return;
  final items = (p['items'] as List).cast<Map>();
  await showDialog<void>(
    context: c,
    builder: (_) => AlertDialog(
      title: const Row(children: [Icon(Icons.verified_outlined, color: kOk), SizedBox(width: 8), Text('Bukti pembayaran')]),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          InfoRow('No. kwitansi', '${p['receipt_no']}'),
          InfoRow('Tanggal', fdt(p['paid_at'])),
          InfoRow('Unit', '${p['unit']?['number'] ?? '-'}'),
          InfoRow('Pembayar', '${p['user']?['name']}'),
          InfoRow('Metode', '${p['method']} (simulasi)'),
          const Divider(height: 22),
          for (final it in items) ...[
            Row(children: [
              Expanded(child: Text('${it['label']}', style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(rp(it['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            for (final k in (it['components'] as List).cast<Map>())
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 2),
                child: Row(children: [
                  Expanded(child: Text('${k['label']}', style: const TextStyle(fontSize: 12, color: kMuted))),
                  Text(rp(k['amount']), style: const TextStyle(fontSize: 12, color: kMuted)),
                ]),
              ),
            const SizedBox(height: 8),
          ],
          const Divider(height: 14),
          Row(children: [
            const Expanded(child: Text('Total dibayar', style: TextStyle(fontWeight: FontWeight.w800))),
            Text(rp(p['amount']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
        ]),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            final r = await guard(c, () => Api.get('/apartments/$aptId/payments/$id/pdf-link'));
            if (r != null && c.mounted) await openUrl(c, '${r['url']}');
          },
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('Unduh PDF'),
        ),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup')),
      ],
    ),
  );
}

// ---------------------------------------------------------------- Daftar CRUD generik
class CrudList extends StatelessWidget {
  final String path, addLabel, emptyTitle, emptyHint;
  final List<Field> fields;
  final bool canEdit;
  final Widget Function(Map m) builder;
  final Map<String, dynamic>? defaults;
  final void Function(BuildContext c, Map m)? onView;
  final List<(IconData, String, Future<bool> Function(BuildContext, Map))> extra;
  const CrudList({
    super.key,
    required this.path,
    required this.fields,
    required this.canEdit,
    required this.builder,
    this.addLabel = 'Tambah',
    this.emptyTitle = 'Belum ada data',
    this.emptyHint = '',
    this.defaults,
    this.onView,
    this.extra = const [],
  });

  Future<void> _create(BuildContext c, Future<void> Function() reload) async {
    final f = await showForm(c, title: addLabel, fields: fields, initial: defaults);
    if (f == null || !c.mounted) return;
    if (await guard(c, () => Api.post(path, f), ok: 'Data ditambahkan.') != null) await reload();
  }

  Future<void> _tap(BuildContext c, Map m, Future<void> Function() reload) async {
    if (!canEdit) {
      onView?.call(c, m);
      return;
    }
    final i = await actionSheet(c, 'Pilih tindakan', [(Icons.edit_outlined, 'Ubah'), (Icons.delete_outline, 'Hapus'), for (final e in extra) (e.$1, e.$2)]);
    if (i == null || !c.mounted) return;
    if (i == 0) {
      final f = await showForm(c, title: 'Ubah data', fields: fields, initial: m.cast<String, dynamic>());
      if (f == null || !c.mounted) return;
      if (await guard(c, () => Api.put('$path/${m['id']}', f), ok: 'Perubahan disimpan.') != null) await reload();
    } else if (i >= 2) {
      if (await extra[i - 2].$3(c, m)) await reload();
    } else {
      if (!await confirmDlg(c, 'Hapus data ini?', 'Tindakan ini tidak dapat dibatalkan.', ok: 'Hapus')) return;
      if (!c.mounted) return;
      if (await guard(c, () => Api.delete('$path/${m['id']}'), ok: 'Data dihapus.') != null) await reload();
    }
  }

  @override
  Widget build(BuildContext context) => Loader(
        load: () => Api.get(path),
        builder: (c, data, reload) {
          final list = (data as List).cast<Map>();
          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: canEdit ? FloatingActionButton.extended(onPressed: () => _create(c, reload), icon: const Icon(Icons.add), label: Text(addLabel)) : null,
            body: refreshList(reload, [
              if (list.isEmpty) Empty(Icons.inbox_outlined, emptyTitle, emptyHint),
              for (final m in list) Panel(onTap: () => _tap(c, m, reload), child: builder(m)),
            ]),
          );
        },
      );
}

const _catInfo = {
  'info': ('Info', kInfo),
  'penting': ('Penting', kBad),
  'pembayaran': ('Pembayaran', kBrass),
  'perawatan': ('Perawatan', kPine),
};

class AnnouncementsList extends StatelessWidget {
  final int aptId;
  final bool canEdit;
  const AnnouncementsList({super.key, required this.aptId, required this.canEdit});

  @override
  Widget build(BuildContext context) => CrudList(
        path: '/apartments/$aptId/announcements',
        canEdit: canEdit,
        addLabel: 'Pengumuman baru',
        emptyTitle: 'Belum ada pengumuman',
        defaults: const {'category': 'info'},
        fields: const [
          Field('title', 'Judul', required: true),
          Field('category', 'Kategori', type: 'select', required: true, options: [['info', 'Info'], ['penting', 'Penting'], ['pembayaran', 'Pembayaran'], ['perawatan', 'Perawatan']]),
          Field('body', 'Isi pengumuman', type: 'multiline', required: true),
          Field('is_pinned', 'Sematkan di atas', type: 'switch'),
        ],
        onView: (c, m) => infoDlg(c, '${m['title']}', Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${m['user']?['name'] ?? 'Pengelola'} • ${fdt(m['created_at'])}', style: const TextStyle(color: kMuted, fontSize: 12)),
          const SizedBox(height: 10),
          Text('${m['body']}', style: const TextStyle(height: 1.5)),
        ])),
        builder: (m) {
          final cat = _catInfo['${m['category']}'] ?? _catInfo['info']!;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (m['is_pinned'] == true) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin, size: 16, color: kBrass)),
              Expanded(child: Text('${m['title']}', style: const TextStyle(fontWeight: FontWeight.w700))),
              Pill(cat.$1, cat.$2),
            ]),
            const SizedBox(height: 4),
            Text('${m['body']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 4),
            Text('${m['user']?['name'] ?? ''} • ${fd(m['created_at'])}', style: const TextStyle(color: kMuted, fontSize: 11)),
          ]);
        },
      );
}

class FacilitiesList extends StatelessWidget {
  final int aptId;
  final bool canEdit;
  const FacilitiesList({super.key, required this.aptId, required this.canEdit});

  Future<bool> _photo(BuildContext c, Map m) async {
    final ph = await pickPhoto();
    if (ph == null || !c.mounted) return false;
    final r = await guard(c, () => Api.multipart('/apartments/$aptId/facilities/${m['id']}/photo', files: [('photo', ph.bytes, ph.name)]), ok: 'Foto fasilitas diperbarui.');
    return r != null;
  }

  @override
  Widget build(BuildContext context) => CrudList(
        path: '/apartments/$aptId/facilities',
        canEdit: canEdit,
        extra: canEdit ? [(Icons.photo_camera_outlined, 'Ubah foto', _photo)] : const [],
        addLabel: 'Fasilitas baru',
        emptyTitle: 'Belum ada fasilitas bersama',
        defaults: const {'status': 'available'},
        fields: const [
          Field('name', 'Nama fasilitas', required: true),
          Field('status', 'Status', type: 'select', required: true, options: [['available', 'Tersedia'], ['maintenance', 'Dalam perbaikan'], ['closed', 'Ditutup sementara']]),
          Field('hours', 'Jam operasional', hint: 'mis. 06.00–21.00'),
          Field('location', 'Lokasi'),
          Field('description', 'Deskripsi', type: 'multiline'),
          Field('rules', 'Aturan penggunaan', type: 'multiline'),
        ],
        onView: (c, m) => infoDlg(c, '${m['name']}', Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (m['photo_url'] != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: NetImg('${m['photo_url']}', w: double.infinity, h: 150)),
          InfoRow('Status', facilityStatusLabel('${m['status']}')),
          InfoRow('Jam', '${m['hours'] ?? '-'}'),
          InfoRow('Lokasi', '${m['location'] ?? '-'}'),
          if (m['description'] != null) InfoRow('Deskripsi', '${m['description']}'),
          if (m['rules'] != null) InfoRow('Aturan', '${m['rules']}'),
        ])),
        builder: (m) => Row(children: [
          m['photo_url'] != null ? NetImg('${m['photo_url']}', w: 48, h: 48) : const Icon(Icons.pool_outlined, color: kPine),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${m['hours'] ?? ''}${m['location'] != null ? ' • ${m['location']}' : ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
          ])),
          Pill(facilityStatusLabel('${m['status']}'), statusInfo('${m['status']}').$2),
        ]),
      );
}

class UnitTypesPage extends StatelessWidget {
  final int aptId;
  final bool canEdit;
  const UnitTypesPage({super.key, required this.aptId, required this.canEdit});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBarOf('Tipe unit'),
        body: CrudList(
          path: '/apartments/$aptId/unit-types',
          canEdit: canEdit,
          addLabel: 'Tipe unit baru',
          emptyTitle: 'Belum ada tipe unit',
          defaults: const {'capacity': 2, 'bathrooms': 1, 'bedrooms': 0},
          fields: const [
            Field('name', 'Nama tipe', required: true, hint: 'mis. Studio, 1 Bedroom'),
            Field('rent_price', 'Harga sewa per bulan (Rp)', type: 'number', required: true),
            Field('capacity', 'Kapasitas penghuni', type: 'number'),
            Field('area', 'Luas (m²)', type: 'number'),
            Field('bedrooms', 'Kamar tidur', type: 'number'),
            Field('bathrooms', 'Kamar mandi', type: 'number'),
            Field('features', 'Fasilitas unit (pisahkan dengan koma)', type: 'csv', hint: 'AC, Wi-Fi, Dapur'),
          ],
          onView: (c, m) => infoDlg(c, '${m['name']}', Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            InfoRow('Sewa', '${rp(m['rent_price'])}/bulan'),
            InfoRow('Kapasitas', '${m['capacity']} orang'),
            InfoRow('Luas', '${m['area'] ?? '-'} m²'),
            InfoRow('Fasilitas', ((m['features'] ?? []) as List).join(', ')),
          ])),
          builder: (m) => Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text('${m['units_count'] ?? 0} unit • maks. ${m['capacity']} orang${m['area'] != null ? ' • ${m['area']} m²' : ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
              if (((m['features'] ?? []) as List).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(((m['features']) as List).join(' • '), style: const TextStyle(color: kMuted, fontSize: 11))),
            ])),
            Text(rp(m['rent_price']), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- Layanan tambahan
class ServicesPage extends StatefulWidget {
  final int aptId;
  const ServicesPage({super.key, required this.aptId});
  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  static const fields = [
    Field('name', 'Nama layanan', required: true, hint: 'mis. Member Gym'),
    Field('price', 'Tarif per bulan (Rp)', type: 'number', required: true),
    Field('description', 'Deskripsi', type: 'multiline'),
    Field('is_active', 'Layanan aktif', type: 'switch'),
  ];

  Future<void> _subs(BuildContext c, Map s) async {
    final occ = await guard(c, () => Api.get('/apartments/${widget.aptId}/occupancies'));
    if (occ == null || !c.mounted) return;
    final primaries = (occ as List).cast<Map>().where((o) => o['is_primary'] == true).toList();
    final sub = <int>{for (final x in (s['subscriptions'] as List).cast<Map>()) x['occupancy_id'] as int};
    await showDialog<void>(
      context: c,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Pelanggan ${s['name']}'),
          content: SizedBox(
            width: double.maxFinite,
            child: primaries.isEmpty
                ? const Text('Belum ada penghuni utama aktif.')
                : ListView(shrinkWrap: true, children: [
                    for (final o in primaries)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: sub.contains(o['id'] as int),
                        title: Text('Unit ${o['unit']?['number']} — ${o['user']?['name']}'),
                        onChanged: (v) async {
                          final r = await guard(c, () => v == true ? Api.post('/apartments/${widget.aptId}/services/${s['id']}/subscribe', {'occupancy_id': o['id']}) : Api.delete('/apartments/${widget.aptId}/services/${s['id']}/subscribe/${o['id']}'));
                          if (r != null) setS(() => v == true ? sub.add(o['id'] as int) : sub.remove(o['id'] as int));
                        },
                      ),
                  ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Selesai'))],
        ),
      ),
    );
  }

  Future<void> _tap(BuildContext c, Map s, Future<void> Function() reload) async {
    final i = await actionSheet(c, '${s['name']}', const [(Icons.people_outline, 'Atur pelanggan'), (Icons.edit_outlined, 'Ubah layanan'), (Icons.delete_outline, 'Hapus layanan')]);
    if (i == null || !c.mounted) return;
    if (i == 0) {
      await _subs(c, s);
      await reload();
    } else if (i == 1) {
      final f = await showForm(c, title: 'Ubah layanan', fields: fields, initial: s.cast<String, dynamic>());
      if (f == null || !c.mounted) return;
      if (await guard(c, () => Api.put('/apartments/${widget.aptId}/services/${s['id']}', f), ok: 'Layanan diperbarui.') != null) await reload();
    } else {
      if (!await confirmDlg(c, 'Hapus layanan?', 'Layanan dan pendaftaran pelanggannya akan dihapus.', ok: 'Hapus')) return;
      if (!c.mounted) return;
      if (await guard(c, () => Api.delete('/apartments/${widget.aptId}/services/${s['id']}'), ok: 'Layanan dihapus.') != null) await reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBarOf('Layanan tambahan'),
        body: Loader(
          load: () => Api.get('/apartments/${widget.aptId}/services'),
          builder: (c, data, reload) {
            final list = (data as List).cast<Map>();
            return Scaffold(
              backgroundColor: Colors.transparent,
              floatingActionButton: FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('Layanan'),
                onPressed: () async {
                  final f = await showForm(c, title: 'Layanan baru', fields: fields, initial: const {'is_active': true});
                  if (f == null || !c.mounted) return;
                  if (await guard(c, () => Api.post('/apartments/${widget.aptId}/services', f), ok: 'Layanan ditambahkan.') != null) await reload();
                },
              ),
              body: refreshList(reload, [
                const Padding(padding: EdgeInsets.fromLTRB(4, 6, 4, 12), child: Text('Layanan dihitung otomatis di akhir bulan dan ditagihkan ke penghuni utama yang terdaftar.', style: TextStyle(color: kMuted, fontSize: 13))),
                if (list.isEmpty) const Empty(Icons.room_service_outlined, 'Belum ada layanan', 'Contoh: member gym, sarapan, parkir motor.'),
                for (final s in list)
                  Panel(
                    onTap: () => _tap(c, s, reload),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${s['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${rp(s['price'])}/bulan • ${(s['subscriptions'] as List).length} pelanggan', style: const TextStyle(color: kMuted, fontSize: 12)),
                      ])),
                      s['is_active'] == true ? const Pill('Aktif', kOk) : const Pill('Nonaktif', kMuted),
                    ]),
                  ),
              ]),
            );
          },
        ),
      );
}

// ---------------------------------------------------------------- Admin
class AdminsPage extends StatelessWidget {
  final int aptId;
  const AdminsPage({super.key, required this.aptId});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBarOf('Admin apartemen'),
        body: Loader(
          load: () => Api.get('/apartments/$aptId/admins'),
          builder: (c, data, reload) {
            final list = (data as List).cast<Map>();
            return Scaffold(
              backgroundColor: Colors.transparent,
              floatingActionButton: FloatingActionButton.extended(
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Admin'),
                onPressed: () async {
                  final f = await showForm(c, title: 'Tambah admin', submit: 'Tambahkan', fields: const [Field('email', 'Email akun terdaftar', required: true, hint: 'Akun harus sudah mendaftar di MyHously')]);
                  if (f == null || !c.mounted) return;
                  if (await guard(c, () => Api.post('/apartments/$aptId/admins', f), ok: 'Undangan admin dikirim. Admin perlu menerimanya dari daftar apartemennya.') != null) await reload();
                },
              ),
              body: refreshList(reload, [
                for (final m in list)
                  Panel(
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${m['user']?['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${m['user']?['email']} • ${m['user']?['phone'] ?? ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
                      ])),
                      if (m['role'] == 'owner') const Pill('Owner', kPine) else if (m['invite_status'] == 'pending') const Pill('Menunggu persetujuan', kWarn) else if (m['is_active'] == true) const Pill('Admin', kInfo) else const Pill('Nonaktif', kMuted),
                      if (m['role'] == 'admin' && (m['is_active'] == true || m['invite_status'] == 'pending'))
                        IconButton(
                          icon: const Icon(Icons.person_off_outlined, color: kBad),
                          onPressed: () async {
                            if (!await confirmDlg(c, 'Nonaktifkan admin?', '${m['user']?['name']} tidak lagi dapat mengelola apartemen ini.', ok: 'Nonaktifkan')) return;
                            if (!c.mounted) return;
                            if (await guard(c, () => Api.delete('/apartments/$aptId/admins/${m['user_id']}'), ok: 'Admin dinonaktifkan.') != null) await reload();
                          },
                        ),
                    ]),
                  ),
              ]),
            );
          },
        ),
      );
}

// ---------------------------------------------------------------- Pengaturan
class SettingsPage extends StatelessWidget {
  final int aptId;
  final String role;
  const SettingsPage({super.key, required this.aptId, required this.role});

  static const modLabels = {
    'facilities': 'Fasilitas bersama',
    'services': 'Layanan tambahan',
    'announcements': 'Pengumuman',
    'reports': 'Laporan kerusakan',
    'fines': 'Denda keterlambatan',
    'move_out': 'Permintaan keluar penghuni',
  };

  Future<void> _edit(BuildContext c, String title, List<Field> fields, Map<String, dynamic> initial, Future<void> Function() reload, {Map<String, dynamic> Function(Map<String, dynamic>)? map}) async {
    final f = await showForm(c, title: title, fields: fields, initial: initial);
    if (f == null || !c.mounted) return;
    if (await guard(c, () => Api.put('/apartments/$aptId', map != null ? map(f) : f), ok: 'Pengaturan disimpan.') != null) await reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBarOf('Pengaturan apartemen'),
        body: Loader(
          load: () => Api.get('/apartments/$aptId'),
          builder: (c, a, reload) {
            final amap = (a as Map).cast<String, dynamic>();
            final mods = (a['modules'] as List).cast<String>();
            final owner = role == 'owner';
            const lateFields = [Field('late_fee_per_day', 'Denda per hari per unit (Rp)', type: 'number', required: true), Field('late_fee_cap', 'Batas maksimal denda (Rp, kosongkan jika tanpa batas)', type: 'number')];
            return refreshList(reload, [
              SectionTitle('Informasi', trailing: TextButton(onPressed: () => _edit(c, 'Informasi apartemen', const [
                    Field('name', 'Nama apartemen', required: true),
                    Field('address', 'Alamat', required: true),
                    Field('city', 'Kota'),
                    Field('contact', 'Kontak pengelola'),
                    Field('description', 'Deskripsi', type: 'multiline'),
                    Field('rules', 'Peraturan apartemen', type: 'multiline'),
                  ], amap, reload), child: const Text('Ubah'))),
              Panel(child: Column(children: [
                InfoRow('Nama', '${a['name']}'),
                InfoRow('Alamat', '${a['address']}'),
                InfoRow('Kota', '${a['city'] ?? '-'}'),
                InfoRow('Kontak', '${a['contact'] ?? '-'}'),
                InfoRow('Peraturan', '${(a['rules'] ?? '').toString().isEmpty ? '-' : a['rules']}'),
              ])),
              const SectionTitle('Foto apartemen'),
              Panel(child: Row(children: [
                if (a['photo_url'] != null) Padding(padding: const EdgeInsets.only(right: 12), child: NetImg('${a['photo_url']}', w: 72, h: 72)),
                Expanded(child: Text(a['photo_url'] == null ? 'Belum ada foto.' : 'Foto tampil di informasi apartemen untuk penghuni.', style: const TextStyle(color: kMuted))),
                OutlinedButton(
                  onPressed: () async {
                    final ph = await pickPhoto();
                    if (ph == null || !c.mounted) return;
                    if (await guard(c, () => Api.multipart('/apartments/$aptId/photo', files: [('photo', ph.bytes, ph.name)]), ok: 'Foto apartemen diperbarui.') != null) await reload();
                  },
                  child: const Text('Pilih foto'),
                ),
              ])),
              const SectionTitle('Pengajuan unit lewat kode apartemen'),
              Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Izinkan calon penghuni mengajukan unit'),
                  subtitle: const Text('Calon penghuni memasukkan kode apartemen, memilih unit yang tersedia, lalu menunggu persetujuan Admin.', style: TextStyle(fontSize: 12)),
                  value: a['allow_unit_requests'] == true,
                  onChanged: (v) async {
                    if (await guard(c, () => Api.put('/apartments/$aptId', {'allow_unit_requests': v}), ok: 'Pengaturan disimpan.') != null) await reload();
                  },
                ),
                if (a['join_code'] != null)
                  Row(children: [
                    Expanded(child: SelectableText('${a['join_code']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontFamily: 'monospace'))),
                    TextButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: '${a['join_code']}')); if (c.mounted) toast(c, 'Kode disalin.'); }, child: const Text('Salin')),
                  ]),
                OutlinedButton(
                  onPressed: () async {
                    if (await guard(c, () => Api.post('/apartments/$aptId/join-code'), ok: 'Kode apartemen dibuat.') != null) await reload();
                  },
                  child: Text(a['join_code'] == null ? 'Buat kode apartemen' : 'Buat ulang kode'),
                ),
              ])),
              SectionTitle('Denda keterlambatan', trailing: TextButton(onPressed: () => _edit(c, 'Denda keterlambatan', lateFields, amap, reload), child: const Text('Ubah'))),
              Panel(child: Column(children: [
                InfoRow('Per hari per unit', rp(a['late_fee_per_day'])),
                InfoRow('Batas maksimal', a['late_fee_cap'] == null ? 'Tanpa batas' : rp(a['late_fee_cap'])),
              ])),
              SectionTitle('Biaya & jadwal tagihan', trailing: owner ? TextButton(onPressed: () => _edit(c, 'Biaya & jadwal tagihan', const [
                    Field('service_fee', 'Service charge per bulan (Rp)', type: 'number'),
                    Field('electricity_fee', 'Listrik per bulan (Rp)', type: 'number'),
                    Field('water_fee', 'Air per bulan (Rp)', type: 'number'),
                    Field('rent_issue_day', 'Tagihan sewa terbit tanggal (1–28)', type: 'number'),
                    Field('due_day', 'Jatuh tempo tanggal (1–28)', type: 'number'),
                  ], amap, reload), child: const Text('Ubah')) : null),
              Panel(child: Column(children: [
                InfoRow('Service charge', rp(a['service_fee'])),
                InfoRow('Listrik', rp(a['electricity_fee'])),
                InfoRow('Air', rp(a['water_fee'])),
                InfoRow('Tagihan terbit', 'tanggal ${a['rent_issue_day']}'),
                InfoRow('Jatuh tempo', 'tanggal ${a['due_day']} bulan berikutnya'),
                if (!owner) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Biaya dan jadwal hanya dapat diubah oleh Owner.', style: TextStyle(color: kMuted, fontSize: 12))),
              ])),
              SectionTitle('Fitur yang dipakai', trailing: owner ? TextButton(
                      onPressed: () => _edit(
                        c,
                        'Fitur apartemen',
                        [for (final e in modLabels.entries) Field('m_${e.key}', e.value, type: 'switch')],
                        {for (final k in modLabels.keys) 'm_$k': mods.contains(k)},
                        reload,
                        map: (f) => {'modules': [for (final k in modLabels.keys) if (f['m_$k'] == true) k]},
                      ),
                      child: const Text('Ubah')) : null),
              Panel(child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in modLabels.entries) Pill(e.value, mods.contains(e.key) ? kOk : kMuted),
              ])),
            ]);
          },
        ),
      );
}

// ---------------------------------------------------------------- Notifikasi
class NotificationsPage extends StatelessWidget {
  final int? aptId;
  const NotificationsPage({super.key, this.aptId});

  IconData _icon(String t) => switch (t) {
        'bill' => Icons.receipt_long_outlined,
        'payment' => Icons.check_circle_outline,
        'fine' => Icons.warning_amber_rounded,
        'report' => Icons.build_circle_outlined,
        'announcement' => Icons.campaign_outlined,
        'join' => Icons.vpn_key_outlined,
        'moveout' => Icons.logout,
        'reminder' => Icons.alarm_outlined,
        _ => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBarOf('Notifikasi'),
        body: Loader(
          load: () => Api.get('/notifications', q: aptId == null ? null : {'apartment_id': aptId}),
          builder: (c, data, reload) {
            final list = (data as List).cast<Map>();
            return refreshList(reload, [
              if (list.any((n) => n['read_at'] == null))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      if (await guard(c, () => Api.post('/notifications/read-all')) != null) await reload();
                    },
                    child: const Text('Tandai semua dibaca'),
                  ),
                ),
              if (list.isEmpty) const Empty(Icons.notifications_none, 'Belum ada notifikasi'),
              for (final n in list)
                Panel(
                  color: n['read_at'] == null ? kPine.withAlpha(12) : null,
                  onTap: () async {
                    if (n['read_at'] == null) {
                      await guard(c, () => Api.post('/notifications/${n['id']}/read'));
                      await reload();
                    }
                  },
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconBadge(_icon('${n['type']}'), color: n['read_at'] == null ? kPine : kMuted, size: 40),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${n['title']}', style: TextStyle(fontWeight: n['read_at'] == null ? FontWeight.w800 : FontWeight.w600)),
                      if (n['body'] != null && '${n['body']}'.isNotEmpty) Text('${n['body']}', style: const TextStyle(color: kMuted, fontSize: 13)),
                      Text(fdt(n['created_at']), style: const TextStyle(color: kMuted, fontSize: 11)),
                    ])),
                  ]),
                ),
            ]);
          },
        ),
      );
}

// ---------------------------------------------------------------- Laporan kerusakan
class ReportsPage extends StatefulWidget {
  final int aptId;
  final bool staff;
  const ReportsPage({super.key, required this.aptId, required this.staff});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String filter = 'all';
  int tick = 0;

  Future<void> _create(BuildContext c) async {
    final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => NewReportPage(aptId: widget.aptId)));
    if (ok == true) setState(() => tick++);
  }

  @override
  Widget build(BuildContext context) => Loader(
        key: ValueKey('$filter-$tick'),
        load: () => Api.get('/apartments/${widget.aptId}/reports', q: filter == 'all' ? null : {'status': filter}),
        builder: (c, data, reload) {
          final list = (data as List).cast<Map>();
          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: widget.staff ? null : FloatingActionButton.extended(onPressed: () => _create(c), icon: const Icon(Icons.add), label: const Text('Lapor')),
            body: Column(children: [
              ChipsBar(const [['all', 'Semua'], ['menunggu', 'Menunggu'], ['diterima', 'Diterima'], ['ditangani', 'Ditangani'], ['selesai', 'Selesai'], ['ditolak', 'Ditolak']], filter, (v) => setState(() => filter = v)),
              Expanded(
                child: refreshList(reload, [
                  if (list.isEmpty) Empty(Icons.build_circle_outlined, 'Belum ada laporan', widget.staff ? '' : 'Laporkan kerusakan di unit atau fasilitas bersama.'),
                  for (final r in list)
                    Panel(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportDetailPage(aptId: widget.aptId, id: r['id'] as int, staff: widget.staff))).then((_) => setState(() => tick++)),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${r['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${r['facility'] != null ? r['facility']['name'] : 'Unit ${r['unit']?['number'] ?? '-'}'}${widget.staff ? ' • ${r['user']?['name']}' : ''} • ${fd(r['created_at'])}', style: const TextStyle(color: kMuted, fontSize: 12)),
                        ])),
                        Pill.status('${r['status']}'),
                      ]),
                    ),
                ]),
              ),
            ]),
          );
        },
      );
}

class ReportDetailPage extends StatelessWidget {
  final int aptId, id;
  final bool staff;
  const ReportDetailPage({super.key, required this.aptId, required this.id, required this.staff});

  static const flow = {
    'menunggu': ['diterima', 'ditolak'],
    'diterima': ['ditangani', 'selesai'],
    'ditangani': ['selesai'],
  };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBarOf('Detail laporan'),
        body: Loader(
          load: () => Api.get('/apartments/$aptId/reports/$id'),
          builder: (c, r, reload) {
            final ups = (r['updates'] as List).cast<Map>();
            final next = flow['${r['status']}'] ?? const <String>[];
            return refreshList(reload, [
              Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text('${r['title']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), Pill.status('${r['status']}')]),
                const SizedBox(height: 8),
                Text('${r['description']}', style: const TextStyle(height: 1.45)),
                if (((r['photos'] ?? []) as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final ph in (r['photos'] as List).cast<Map>())
                        GestureDetector(
                          onTap: () => showDialog<void>(context: c, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network('${ph['url']}')))),
                          child: NetImg('${ph['url']}', w: 90, h: 90),
                        ),
                    ]),
                  ),
                const Divider(height: 22),
                InfoRow('Lokasi', r['facility'] != null ? '${r['facility']['name']}' : 'Unit ${r['unit']?['number'] ?? '-'}'),
                InfoRow('Pelapor', '${r['user']?['name']}'),
                InfoRow('Dilaporkan', fdt(r['created_at'])),
                if (r['reject_reason'] != null) InfoRow('Alasan penolakan', '${r['reject_reason']}'),
              ])),
              if (staff && next.isNotEmpty) ...[
                const SectionTitle('Perbarui status'),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  for (final s in next)
                    (s == 'ditolak' ? OutlinedButton(onPressed: () => _set(c, s, reload), child: Text('Tolak laporan')) : FilledButton(onPressed: () => _set(c, s, reload), child: Text(switch (s) { 'diterima' => 'Terima laporan', 'ditangani' => 'Mulai ditangani', _ => 'Tandai selesai' }))),
                ]),
              ],
              const SectionTitle('Riwayat status'),
              for (final u in ups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 4, right: 10), child: Icon(Icons.circle, size: 12, color: statusInfo('${u['status']}').$2)),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(statusInfo('${u['status']}').$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (u['note'] != null) Text('${u['note']}'),
                      Text('${u['user']?['name'] ?? ''} • ${fdt(u['created_at'])}', style: const TextStyle(color: kMuted, fontSize: 11)),
                    ])),
                  ]),
                ),
            ]);
          },
        ),
      );

  Future<void> _set(BuildContext c, String status, Future<void> Function() reload) async {
    final f = await showForm(c, title: 'Perbarui status', submit: 'Simpan', fields: [
      Field('note', status == 'ditolak' ? 'Alasan penolakan' : 'Catatan untuk penghuni', type: 'multiline', required: status == 'ditolak'),
    ]);
    if (f == null || !c.mounted) return;
    if (await guard(c, () => Api.post('/apartments/$aptId/reports/$id/status', {'status': status, ...f}), ok: 'Status diperbarui.') != null) await reload();
  }
}

// ---------------------------------------------------------------- Profil
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: appBarOf('Profil'), body: const ProfileBody());
}

class ProfileBody extends StatelessWidget {
  final int? aptId;
  final bool moveOut;
  const ProfileBody({super.key, this.aptId, this.moveOut = false});

  Future<dynamic> _load() async {
    final me = await Api.get('/me');
    var outs = <dynamic>[];
    if (moveOut && aptId != null) {
      try {
        outs = (await Api.get('/apartments/$aptId/move-out')) as List;
      } catch (_) {}
    }
    return {'me': me, 'outs': outs};
  }

  @override
  Widget build(BuildContext context) => Loader(
        load: _load,
        builder: (c, d, reload) {
          final u = (d['me']['user'] as Map).cast<String, dynamic>();
          Session.user = u;
          final outs = (d['outs'] as List).cast<Map>();
          return refreshList(reload, [
            Panel(child: Row(children: [
              Avatar(u['photo_url'] as String?, '${u['name']}', radius: 28),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${u['name']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('${u['email']}', style: const TextStyle(color: kMuted, fontSize: 13)),
                Text('${u['phone'] ?? '-'}', style: const TextStyle(color: kMuted, fontSize: 13)),
                if (u['hometown'] != null) Text('Asal: ${u['hometown']}${u['gender'] != null ? ' • ${u['gender'] == 'L' ? 'Laki-laki' : 'Perempuan'}' : ''}', style: const TextStyle(color: kMuted, fontSize: 13)),
                if (u['emergency_name'] != null) Text('Kontak darurat: ${u['emergency_name']} (${u['emergency_phone'] ?? '-'})', style: const TextStyle(color: kMuted, fontSize: 13)),
              ])),
            ])),
            Panel(
              onTap: () async {
                final f = await showForm(c, title: 'Ubah profil', initial: u, fields: const [
                  Field('name', 'Nama lengkap', required: true),
                  Field('phone', 'Nomor telepon', required: true),
                  Field('gender', 'Jenis kelamin', type: 'select', options: [['L', 'Laki-laki'], ['P', 'Perempuan']]),
                  Field('hometown', 'Asal daerah'),
                  Field('emergency_name', 'Nama kontak darurat'),
                  Field('emergency_phone', 'Nomor kontak darurat'),
                ]);
                if (f == null || !c.mounted) return;
                if (await guard(c, () => Api.put('/me', f), ok: 'Profil diperbarui.') != null) await reload();
              },
              child: const Row(children: [Icon(Icons.edit_outlined, color: kPine), SizedBox(width: 12), Expanded(child: Text('Ubah profil', style: TextStyle(fontWeight: FontWeight.w600))), Icon(Icons.chevron_right)]),
            ),
            Panel(
              onTap: () async {
                final ph = await pickPhoto();
                if (ph == null || !c.mounted) return;
                if (await guard(c, () => Api.multipart('/me/photo', files: [('photo', ph.bytes, ph.name)]), ok: 'Foto profil diperbarui.') != null) await reload();
              },
              child: const Row(children: [Icon(Icons.photo_camera_outlined, color: kPine), SizedBox(width: 12), Expanded(child: Text('Ubah foto profil', style: TextStyle(fontWeight: FontWeight.w600))), Icon(Icons.chevron_right)]),
            ),
            Panel(
              onTap: () async {
                final f = await showForm(c, title: 'Ganti kata sandi', fields: const [Field('current_password', 'Kata sandi saat ini', type: 'password', required: true), Field('password', 'Kata sandi baru (min. 6 karakter)', type: 'password', required: true)]);
                if (f == null || !c.mounted) return;
                await guard(c, () => Api.put('/me', f), ok: 'Kata sandi diganti.');
              },
              child: const Row(children: [Icon(Icons.lock_outline, color: kPine), SizedBox(width: 12), Expanded(child: Text('Ganti kata sandi', style: TextStyle(fontWeight: FontWeight.w600))), Icon(Icons.chevron_right)]),
            ),
            if (moveOut && aptId != null) ...[
              const SectionTitle('Permintaan keluar'),
              for (final o in outs)
                Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text('Rencana keluar ${fd(o['desired_date'])}', style: const TextStyle(fontWeight: FontWeight.w700))), Pill.status('${o['status']}')]),
                  if (o['reason'] != null) Text('${o['reason']}', style: const TextStyle(fontSize: 13)),
                  if (o['note'] != null) Text('Catatan pengelola: ${o['note']}', style: const TextStyle(color: kMuted, fontSize: 12)),
                ])),
              OutlinedButton.icon(
                onPressed: () async {
                  final f = await showForm(c, title: 'Ajukan keluar dari unit', submit: 'Kirim permintaan', fields: const [Field('desired_date', 'Tanggal rencana keluar', type: 'date', required: true), Field('reason', 'Alasan', type: 'multiline')]);
                  if (f == null || !c.mounted) return;
                  if (await guard(c, () => Api.post('/apartments/$aptId/move-out', f), ok: 'Permintaan keluar dikirim.') != null) await reload();
                },
                icon: const Icon(Icons.logout),
                label: const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Ajukan keluar dari unit')),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: () async {
                if (await confirmDlg(c, 'Keluar dari akun?', 'Anda perlu masuk kembali untuk mengakses MyHously.', ok: 'Keluar')) await doLogout(c);
              },
              icon: const Icon(Icons.logout),
              label: const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Keluar')),
            ),
          ]);
        },
      );
}

// ---------------------------------------------------------------- Lonceng notifikasi (polling)
class NotifBell extends StatefulWidget {
  final int? aptId;
  const NotifBell({super.key, this.aptId});
  @override
  State<NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends State<NotifBell> {
  int count = 0;
  int? lastId;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _poll();
    timer = Timer.periodic(const Duration(seconds: 25), (_) => _poll());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final r = await Api.get('/notifications/unread');
      if (!mounted) return;
      final latest = r['latest'] as Map?;
      final id = latest == null ? null : latest['id'] as int;
      if (lastId != null && id != null && id != lastId && mounted) toast(context, '${latest!['title']}');
      setState(() {
        count = (r['count'] as num).toInt();
        lastId = id;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.notifications_none)),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(aptId: widget.aptId)));
          _poll();
        },
      );
}

// ---------------------------------------------------------------- Laporan baru dengan foto
class NewReportPage extends StatefulWidget {
  final int aptId;
  const NewReportPage({super.key, required this.aptId});
  @override
  State<NewReportPage> createState() => _NewReportPageState();
}

class _NewReportPageState extends State<NewReportPage> {
  final title = TextEditingController();
  final desc = TextEditingController();
  String facility = '';
  List<List<String>> facs = [];
  final photos = <PickedPhoto>[];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    try {
      final r = (await Api.get('/apartments/${widget.aptId}/facilities') as List).cast<Map>();
      if (!mounted) return;
      setState(() => facs = [for (final f in r) ['${f['id']}', '${f['name']}']]);
    } catch (_) {}
  }

  Future<void> _add() async {
    final p = await pickPhotos(max: 3 - photos.length);
    if (p.isNotEmpty) setState(() => photos.addAll(p.take(3 - photos.length)));
  }

  Future<void> _submit() async {
    if (title.text.trim().isEmpty || desc.text.trim().isEmpty) {
      toast(context, 'Judul dan penjelasan masalah wajib diisi.', error: true);
      return;
    }
    setState(() => busy = true);
    final res = await guard(
      context,
      () => Api.multipart('/apartments/${widget.aptId}/reports', fields: {
        'title': title.text.trim(),
        'description': desc.text.trim(),
        if (facility.isNotEmpty) 'facility_id': facility,
      }, files: [for (final p in photos) ('photos[]', p.bytes, p.name)]),
      ok: 'Laporan terkirim.',
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (res != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBarOf('Laporkan masalah'),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
          TextField(controller: title, decoration: deco('Judul masalah *', hint: 'mis. AC tidak dingin')),
          const SizedBox(height: 12),
          TextField(controller: desc, maxLines: 4, decoration: deco('Jelaskan masalahnya *')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: facility,
            isExpanded: true,
            decoration: deco('Lokasi masalah'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Di dalam unit saya')),
              for (final f in facs) DropdownMenuItem(value: f[0], child: Text('Fasilitas: ${f[1]}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => facility = v ?? ''),
          ),
          const SectionTitle('Foto (opsional, maks. 3)'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < photos.length; i++)
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(photos[i].bytes, width: 92, height: 92, fit: BoxFit.cover)),
                Positioned(
                  right: 2,
                  top: 2,
                  child: InkWell(onTap: () => setState(() => photos.removeAt(i)), child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white))),
                ),
              ]),
            if (photos.length < 3)
              InkWell(
                onTap: _add,
                child: Container(width: 92, height: 92, decoration: BoxDecoration(border: Border.all(color: kLine), borderRadius: BorderRadius.circular(10), color: Colors.white), child: const Icon(Icons.add_a_photo_outlined, color: kMuted)),
              ),
          ]),
          const SizedBox(height: 4),
          const Text('Format gambar, maksimal 4 MB per foto.', style: TextStyle(color: kMuted, fontSize: 12)),
          const SizedBox(height: 22),
          FilledButton(onPressed: busy ? null : _submit, child: Padding(padding: const EdgeInsets.symmetric(vertical: 13), child: Text(busy ? 'Mengirim...' : 'Kirim laporan'))),
        ]),
      );
}
