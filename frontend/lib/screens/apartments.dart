import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';
import '../main.dart';
import 'auth.dart';
import 'common.dart';
import 'staff.dart';
import 'tenant.dart';

String roleLabel(String r) => r == 'owner' ? 'Owner' : (r == 'admin' ? 'Admin' : 'Penghuni');

void openApartment(BuildContext c, Map m) {
  final id = m['apartment_id'] ?? m['apartment']['id'];
  final name = '${m['apartment']['name']}';
  final role = '${m['role']}';
  Navigator.push(c, MaterialPageRoute(builder: (_) => role == 'tenant' ? TenantShell(aptId: id as int, aptName: name) : StaffShell(aptId: id as int, aptName: name, role: role)));
}

Future<void> doLogout(BuildContext context) async {
  try {
    await Api.post('/logout');
  } catch (_) {}
  await Api.setToken(null);
  navKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
}

class ApartmentsPage extends StatefulWidget {
  const ApartmentsPage({super.key});
  @override
  State<ApartmentsPage> createState() => _ApartmentsPageState();
}

class _ApartmentsPageState extends State<ApartmentsPage> {
  Key _k = UniqueKey();
  void refresh() => setState(() => _k = UniqueKey());

  Future<void> join() async {
    final f = await showForm(context, title: 'Gabung ke apartemen', submit: 'Periksa kode', fields: const [Field('code', 'Kode undangan atau kode apartemen', required: true, hint: 'mis. MYH-AB12CD atau GREEN2026')]);
    if (f == null || !mounted) return;
    final p = await guard(context, () => Api.get('/join/preview', q: {'code': f['code']}));
    if (p == null || !mounted) return;
    final body = <String, dynamic>{'code': f['code']};
    if (p['mode'] == 'apartment') {
      final units = (p['units'] as List).cast<Map>();
      final picked = await showDialog<int>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('${p['apartment']['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(shrinkWrap: true, children: [
              const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Pilih unit yang ingin diajukan. Permintaan perlu disetujui pengelola.', style: TextStyle(color: kMuted, fontSize: 12))),
              for (final u in units)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const IconBadge(Icons.meeting_room_outlined, size: 40),
                  title: Text('Unit ${u['number']} • ${u['type']['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${u['building'] != null ? '${u['building']} • ' : ''}Lantai ${u['floor']} • ${rp(u['type']['rent_price'])}/bulan'),
                  onTap: () => Navigator.pop(context, u['id'] as int),
                ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal'))],
        ),
      );
      if (picked == null || !mounted) return;
      body['unit_id'] = picked;
    } else {
      final u = p['unit'];
      final t = u['type'];
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('${p['apartment']['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            InfoRow('Alamat', '${p['apartment']['address']}'),
            InfoRow('Unit', '${u['number']} (lantai ${u['floor']})'),
            InfoRow('Tipe', '${t['name']}'),
            InfoRow('Sewa', rp(t['rent_price'])),
            InfoRow('Peran di unit', p['is_primary'] == true ? 'Penghuni utama' : 'Penghuni tambahan'),
            InfoRow('Mulai', fd(p['start_date'])),
            InfoRow('Deposit', rp(p['deposit'])),
            const SizedBox(height: 10),
            const Text('Permintaan akan dikirim ke pengelola dan perlu disetujui sebelum Anda bergabung.', style: TextStyle(color: kMuted, fontSize: 12)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kirim permintaan')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final r = await guard(context, () => Api.post('/join', body), ok: 'Permintaan dikirim. Tunggu persetujuan pengelola.');
    if (r != null) refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBarOf('MyHously', actions: [
          const NotifBell(),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())).then((_) => refresh())),
        ]),
        body: Loader(
          key: _k,
          load: () => Api.get('/me'),
          builder: (c, data, reload) {
            Session.user = Map<String, dynamic>.from(data['user'] as Map);
            final ms = (data['memberships'] as List).cast<Map>();
            final reqs = (data['requests'] as List).cast<Map>();
            final invs = ((data['admin_invites'] ?? []) as List).cast<Map>();
            final first = Session.user['name'].toString().split(' ').first;
            return refreshList(reload, [
              HeroCard(
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: Avatar(Session.user['photo_url'] as String?, '${Session.user['name']}', radius: 28)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Selamat datang,', style: TextStyle(color: Colors.white70)),
                      Text(first, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text(ms.isEmpty ? 'Belum ada apartemen' : '${ms.length} apartemen terhubung', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
              for (final iv in invs)
                Panel(
                  color: kBrass.withAlpha(30),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const IconBadge(Icons.mark_email_unread_outlined, color: kBrass, size: 40),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Undangan Admin', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${iv['apartment']?['name']}', style: const TextStyle(color: kMuted, fontSize: 13)),
                      ])),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () async {
                        if (await guard(context, () => Api.post('/admin-invites/${iv['id']}/answer', {'accept': false}), ok: 'Undangan ditolak.') != null) reload();
                      }, child: const Text('Tolak'))),
                      const SizedBox(width: 10),
                      Expanded(child: FilledButton(onPressed: () async {
                        if (await guard(context, () => Api.post('/admin-invites/${iv['id']}/answer', {'accept': true}), ok: 'Anda kini menjadi Admin.') != null) reload();
                      }, child: const Text('Terima'))),
                    ]),
                  ]),
                ),
              if (ms.isEmpty) const Empty(Icons.apartment_rounded, 'Belum ada apartemen', 'Gabung dengan kode undangan dari pengelola, atau daftarkan apartemen yang Anda kelola.'),
              if (ms.isNotEmpty) const SectionTitle('Apartemen saya'),
              for (final m in ms)
                Panel(
                  onTap: () => openApartment(context, m),
                  child: Row(children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [kPine, Color(0xFF1B8070)]), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.apartment_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${m['apartment']['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      const SizedBox(height: 3),
                      Text('${m['apartment']['address']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 12.5)),
                    ])),
                    const SizedBox(width: 8),
                    Pill(roleLabel('${m['role']}'), m['role'] == 'tenant' ? kInfo : kPine),
                    const Icon(Icons.chevron_right, color: kMuted),
                  ]),
                ),
              if (reqs.isNotEmpty) const SectionTitle('Permintaan bergabung'),
              for (final r in reqs)
                Panel(
                  child: Row(children: [
                    const IconBadge(Icons.hourglass_top_rounded, color: kWarn, size: 40),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Unit ${r['unit']?['number'] ?? '-'} • ${r['apartment']?['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (r['reject_reason'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${r['reject_reason']}', style: const TextStyle(color: kBad, fontSize: 12))),
                    ])),
                    Pill.status('${r['status']}'),
                    if (r['status'] == 'pending')
                      TextButton(
                        onPressed: () async {
                          if (await guard(context, () => Api.post('/join-requests/${r['id']}/cancel'), ok: 'Permintaan dibatalkan.') != null) reload();
                        },
                        child: const Text('Batal'),
                      ),
                  ]),
                ),
              const SectionTitle('Mulai'),
              AdaptiveGrid([
                _ActionTile(Icons.vpn_key_outlined, 'Gabung dengan kode', 'Dari undangan pengelola', join),
                _ActionTile(Icons.add_business_outlined, 'Daftarkan apartemen', 'Jadi Owner apartemen baru', () async {
                  final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const CreateApartmentPage()));
                  if (created == true) reload();
                }),
              ], wideCols: 2),
            ]);
          },
        ),
      );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  const _ActionTile(this.icon, this.title, this.sub, this.onTap);
  @override
  Widget build(BuildContext context) => Panel(
        margin: EdgeInsets.zero,
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconBadge(icon, color: kPine, size: 44),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: kMuted, fontSize: 12)),
        ]),
      );
}

// ------------------------------------------------------------ Pendaftaran apartemen
class _TypeRow {
  final name = TextEditingController();
  final price = TextEditingController();
  final cap = TextEditingController(text: '2');
  final count = TextEditingController();
  _TypeRow(String n, String p, String c) {
    name.text = n;
    price.text = p;
    count.text = c;
  }
}

class CreateApartmentPage extends StatefulWidget {
  const CreateApartmentPage({super.key});
  @override
  State<CreateApartmentPage> createState() => _CreateApartmentPageState();
}

class _CreateApartmentPageState extends State<CreateApartmentPage> {
  final name = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final contact = TextEditingController();
  final service = TextEditingController(text: '0');
  final electric = TextEditingController(text: '0');
  final water = TextEditingController(text: '0');
  final late = TextEditingController(text: '50000');
  final issueDay = TextEditingController(text: '24');
  final dueDay = TextEditingController(text: '7');
  final floors = TextEditingController(text: '2');
  final prefix = TextEditingController(text: 'A-');
  final building = TextEditingController();
  final rows = <_TypeRow>[_TypeRow('Studio', '2000000', '6')];
  final mods = <String, bool>{'facilities': true, 'services': true, 'announcements': true, 'reports': true, 'fines': true, 'move_out': true};
  static const modLabels = {
    'facilities': 'Fasilitas bersama',
    'services': 'Layanan tambahan (gym, sarapan, parkir)',
    'announcements': 'Pengumuman',
    'reports': 'Laporan kerusakan',
    'fines': 'Denda keterlambatan',
    'move_out': 'Permintaan keluar penghuni',
  };
  bool busy = false;

  int n(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Widget tf(TextEditingController c, String l, {bool num = false, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, keyboardType: num ? TextInputType.number : TextInputType.text, decoration: deco(l, hint: hint)),
      );

  Future<void> submit() async {
    if (name.text.trim().isEmpty || address.text.trim().isEmpty) {
      toast(context, 'Nama dan alamat apartemen wajib diisi.', error: true);
      return;
    }
    final types = <Map<String, dynamic>>[];
    for (final r in rows) {
      if (r.name.text.trim().isEmpty) continue;
      types.add({'name': r.name.text.trim(), 'rent_price': n(r.price), 'capacity': n(r.cap).clamp(1, 6), 'count': n(r.count)});
    }
    if (types.isEmpty) {
      toast(context, 'Tambahkan minimal satu tipe unit.', error: true);
      return;
    }
    setState(() => busy = true);
    final res = await guard(context, () => Api.post('/apartments', {
          'name': name.text.trim(),
          'address': address.text.trim(),
          'city': city.text.trim(),
          'contact': contact.text.trim(),
          'service_fee': n(service),
          'electricity_fee': n(electric),
          'water_fee': n(water),
          'late_fee_per_day': n(late),
          'rent_issue_day': n(issueDay).clamp(1, 28),
          'due_day': n(dueDay).clamp(1, 28),
          'modules': mods.entries.where((e) => e.value).map((e) => e.key).toList(),
          'types': types,
          'floors': n(floors).clamp(1, 60),
          'prefix': prefix.text.trim().isEmpty ? 'A-' : prefix.text.trim(),
          'building': building.text.trim().isEmpty ? null : building.text.trim(),
        }));
    if (!mounted) return;
    setState(() => busy = false);
    if (res != null) {
      toast(context, 'Apartemen berhasil dibuat.');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<int>(0, (s, r) => s + n(r.count));
    return Scaffold(
      appBar: appBarOf('Daftarkan apartemen'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
            const Text('Anda otomatis menjadi Owner. Semua pengaturan ini dapat diubah nanti.', style: TextStyle(color: kMuted, height: 1.5)),
            const SectionTitle('Informasi apartemen'),
            Panel(child: Column(children: [tf(name, 'Nama apartemen *'), tf(address, 'Alamat *'), tf(city, 'Kota'), tf(contact, 'Kontak pengelola')])),
            const SectionTitle('Biaya bulanan (nominal tetap per unit)'),
            Panel(child: Column(children: [
              tf(service, 'Service charge (Rp)', num: true),
              tf(electric, 'Listrik (Rp)', num: true),
              tf(water, 'Air (Rp)', num: true),
              tf(late, 'Denda keterlambatan per hari per unit (Rp)', num: true),
              Row(children: [
                Expanded(child: tf(issueDay, 'Tagihan terbit tanggal', num: true)),
                const SizedBox(width: 12),
                Expanded(child: tf(dueDay, 'Jatuh tempo tanggal', num: true)),
              ]),
            ])),
            const SectionTitle('Fitur yang dipakai'),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(children: [
                for (final e in modLabels.entries) SwitchListTile(title: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600)), value: mods[e.key]!, onChanged: (v) => setState(() => mods[e.key] = v)),
              ]),
            ),
            SectionTitle('Tipe unit & jumlah unit', trailing: TextButton.icon(onPressed: () => setState(() => rows.add(_TypeRow('', '', '4'))), icon: const Icon(Icons.add, size: 18), label: const Text('Tambah tipe'))),
            for (var i = 0; i < rows.length; i++)
              Panel(
                child: Column(children: [
                  Row(children: [
                    Expanded(child: tf(rows[i].name, 'Nama tipe (mis. Studio, 1BR)')),
                    if (rows.length > 1) IconButton(onPressed: () => setState(() => rows.removeAt(i)), icon: const Icon(Icons.delete_outline, color: kBad)),
                  ]),
                  Row(children: [
                    Expanded(flex: 3, child: tf(rows[i].price, 'Sewa/bulan (Rp)', num: true)),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: tf(rows[i].cap, 'Maks. orang', num: true)),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(controller: rows[i].count, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: deco('Jumlah unit')),
                      ),
                    ),
                  ]),
                ]),
              ),
            Panel(child: Column(children: [
              tf(building, 'Nama gedung (opsional)'),
              Row(children: [
                Expanded(child: tf(floors, 'Jumlah lantai', num: true)),
                const SizedBox(width: 12),
                Expanded(child: tf(prefix, 'Awalan nomor unit')),
              ]),
              Align(alignment: Alignment.centerLeft, child: Text('Akan dibuat $total unit yang dibagi rata ke ${n(floors).clamp(1, 60)} lantai (contoh nomor: ${prefix.text.trim().isEmpty ? 'A-' : prefix.text.trim()}101).', style: const TextStyle(color: kMuted, fontSize: 12))),
            ])),
            const SizedBox(height: 10),
            FilledButton(onPressed: busy ? null : submit, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(busy ? 'Menyimpan...' : 'Buat apartemen'))),
          ]),
        ),
      ),
    );
  }
}
