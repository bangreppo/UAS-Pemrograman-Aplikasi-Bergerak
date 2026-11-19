import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../ui.dart';
import 'common.dart';
import 'shell.dart';

class StaffShell extends StatefulWidget {
  final int aptId;
  final String aptName, role;
  const StaffShell({super.key, required this.aptId, required this.aptName, required this.role});
  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    final id = widget.aptId;
    return Loader(
      load: () => Api.get('/apartments/$id'),
      builder: (c, apt, reload) {
        final mods = (apt['modules'] as List).cast<String>();
        final hasReports = mods.contains('reports');
        final tabs = <ShellTab>[
          ShellTab('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded, StaffDashboard(aptId: id, apt: apt, goUnits: () => setState(() => idx = 1), goReports: hasReports ? () => setState(() => idx = 3) : null)),
          ShellTab('Unit', Icons.apartment_outlined, Icons.apartment_rounded, UnitsTab(aptId: id, role: widget.role, mods: mods)),
          ShellTab('Keuangan', Icons.payments_outlined, Icons.payments_rounded, FinanceTab(aptId: id, mods: mods)),
          if (hasReports) ShellTab('Laporan', Icons.build_circle_outlined, Icons.build_circle_rounded, ReportsPage(aptId: id, staff: true)),
          ShellTab('Lainnya', Icons.grid_view_outlined, Icons.grid_view_rounded, MoreTab(aptId: id, apt: apt, role: widget.role, mods: mods, onChanged: reload)),
        ];
        return AppShell(
          title: widget.aptName,
          tabs: tabs,
          index: idx,
          onIndex: (i) => setState(() => idx = i),
          actions: [
            Center(child: Pill(widget.role == 'owner' ? 'Owner' : 'Admin', kPine)),
            NotifBell(aptId: id),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- Dashboard
class StaffDashboard extends StatefulWidget {
  final int aptId;
  final Map apt;
  final VoidCallback goUnits;
  final VoidCallback? goReports;
  const StaffDashboard({super.key, required this.aptId, required this.apt, required this.goUnits, this.goReports});
  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  String period = 'this_month';

  Widget _legend(Color color, String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(color: kMuted, fontSize: 13))),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _tool(IconData icon, String title, String sub, VoidCallback onTap, {Color color = kPine}) => Panel(
        margin: EdgeInsets.zero,
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          IconBadge(icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            Text(sub, style: const TextStyle(color: kMuted, fontSize: 11.5)),
          ])),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final mods = (widget.apt['modules'] as List).cast<String>();
    return Loader(
      key: ValueKey(period),
      load: () => Api.get('/apartments/${widget.aptId}/dashboard', q: {'period': period}),
      builder: (c, d, reload) {
        final u = d['units'] as Map;
        final inc = d['income'] as Map;
        final series = (inc['series'] as List).cast<Map>();
        final maxV = series.fold<num>(0, (m, s) => (s['amount'] as num) > m ? s['amount'] as num : m);
        final out = d['outstanding'] as Map;
        final bs = d['bills_status'] as Map;
        final rep = d['reports'] as Map;
        final total = (u['total'] as num).toInt();
        final occRate = total == 0 ? 0 : ((u['occupied'] as num) / total * 100).round();
        final paidN = (bs['paid'] as num).toInt();
        final unpaidN = (bs['unpaid'] as num).toInt();
        final pendJoin = (d['pending_requests'] as num).toInt();
        final pendOut = (d['pending_moveouts'] as num).toInt();
        final overdueUnits = (d['overdue_units'] as num).toInt();
        final periodLabel = period == 'this_month' ? 'Bulan ini' : (period == 'last_month' ? 'Bulan lalu' : 'Tahun ini');
        final paidPct = paidN + unpaidN == 0 ? 0.0 : paidN / (paidN + unpaidN);

        Future<void> run(String action) async {
          final r = await guard(context, () => Api.post('/apartments/${widget.aptId}/run-billing', {'action': action}));
          if (r != null && context.mounted) {
            toast(context, '${r['message']}');
            await reload();
          }
        }

        Future<void> exportFile(String type) async {
          final r = await guard(context, () => Api.get('/apartments/${widget.aptId}/exports/link', q: {'type': type, 'period': period}));
          if (r != null && context.mounted) await openUrl(context, '${r['url']}');
        }

        Future<void> shift({int days = 0, bool reset = false}) async {
          final r = await guard(context, () => Api.post('/demo/shift', reset ? {'reset': true} : {'days': days}));
          if (r != null && context.mounted) {
            toast(context, '${r['message']}');
            await reload();
          }
        }

        return refreshList(reload, [
          ChipsBar(const [['this_month', 'Bulan ini'], ['last_month', 'Bulan lalu'], ['year', 'Tahun ini']], period, (v) => setState(() => period = v), padding: const EdgeInsets.only(bottom: 12)),
          HeroCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Pendapatan', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text(periodLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 4),
              Text(rp(inc['amount']), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1)),
              const SizedBox(height: 18),
              SizedBox(
                height: 96,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < series.length; i++)
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Container(
                          height: maxV == 0 ? 4 : ((series[i]['amount'] as num) / maxV * 58).clamp(4, 58).toDouble(),
                          margin: const EdgeInsets.symmetric(horizontal: 7),
                          decoration: BoxDecoration(color: i == series.length - 1 ? kBrass : Colors.white.withAlpha(75), borderRadius: BorderRadius.circular(7)),
                        ),
                        const SizedBox(height: 6),
                        Text('${series[i]['label']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
          if (pendJoin + pendOut > 0)
            Panel(
              onTap: widget.goUnits,
              color: kBrass.withAlpha(30),
              child: Row(children: [
                const IconBadge(Icons.notifications_active_outlined, color: kBrass, size: 42),
                const SizedBox(width: 12),
                Expanded(child: Text('${[if (pendJoin > 0) '$pendJoin permintaan bergabung', if (pendOut > 0) '$pendOut permintaan keluar'].join(' • ')} menunggu keputusan', style: const TextStyle(fontWeight: FontWeight.w700))),
                const Icon(Icons.chevron_right),
              ]),
            ),
          Panel(
            child: Row(children: [
              DonutRing(
                value: occRate / 100,
                size: 108,
                stroke: 13,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$occRate%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const Text('terisi', style: TextStyle(color: kMuted, fontSize: 11)),
                ]),
              ),
              const SizedBox(width: 20),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tingkat hunian', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 6),
                _legend(kPine, 'Terisi', (u['occupied'] as num).toInt()),
                _legend(kOk, 'Tersedia', (u['available'] as num).toInt()),
                _legend(kMuted, 'Tidak tersedia', (u['maintenance'] as num).toInt()),
              ])),
            ]),
          ),
          AdaptiveGrid([
            StatTile('Penghuni aktif', '${d['active_tenants']}', Icons.groups_outlined),
            StatTile('Unit terlambat', '$overdueUnits', Icons.warning_amber_rounded, color: overdueUnits > 0 ? kBad : kOk),
            StatTile('Tagihan belum lunas', rp(out['bills']), Icons.receipt_long_outlined, color: kWarn),
            StatTile('Denda berjalan', rp(out['fines']), Icons.gavel_outlined, color: kBad),
          ]),
          const SectionTitle('Penagihan periode ini'),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Tagihan jatuh tempo', style: TextStyle(fontWeight: FontWeight.w700))),
                Text('${(paidPct * 100).round()}% lunas', style: const TextStyle(color: kOk, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: paidPct, minHeight: 10, backgroundColor: kWarn.withAlpha(60), valueColor: const AlwaysStoppedAnimation(kOk))),
              const SizedBox(height: 8),
              Text('$paidN lunas • $unpaidN belum lunas', style: const TextStyle(color: kMuted, fontSize: 12)),
            ]),
          ),
          if (mods.contains('reports')) ...[
            const SectionTitle('Laporan kerusakan'),
            Panel(
              onTap: widget.goReports,
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in ['menunggu', 'diterima', 'ditangani', 'selesai', 'ditolak']) Pill('${statusInfo(k).$1}: ${rep[k]}', statusInfo(k).$2),
              ]),
            ),
          ],
          const SectionTitle('Aksi cepat'),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tagihan sewa terbit otomatis tanggal ${widget.apt['rent_issue_day']} dan jatuh tempo tanggal ${widget.apt['due_day']} bulan berikutnya. Layanan tambahan dihitung akhir bulan. Denda ${rp(widget.apt['late_fee_per_day'])} per hari per unit berjalan otomatis setelah jatuh tempo.', style: const TextStyle(fontSize: 13, height: 1.5, color: kMuted)),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.tonalIcon(onPressed: () => run('rent'), icon: const Icon(Icons.receipt_long_outlined, size: 18), label: const Text('Terbitkan tagihan sewa')),
                if (mods.contains('services')) FilledButton.tonalIcon(onPressed: () => run('extras'), icon: const Icon(Icons.room_service_outlined, size: 18), label: const Text('Tagihan layanan')),
                if (mods.contains('fines')) FilledButton.tonalIcon(onPressed: () => run('fines'), icon: const Icon(Icons.gavel_outlined, size: 18), label: const Text('Hitung denda')),
              ]),
            ]),
          ),
          const SectionTitle('Ekspor & laporan'),
          AdaptiveGrid([
            _tool(Icons.picture_as_pdf_outlined, 'Laporan keuangan', 'PDF • $periodLabel', () => exportFile('finance'), color: kBad),
            _tool(Icons.table_chart_outlined, 'Pembayaran', 'CSV • $periodLabel', () => exportFile('payments')),
            _tool(Icons.table_chart_outlined, 'Tagihan', 'CSV • $periodLabel', () => exportFile('bills')),
            _tool(Icons.table_chart_outlined, 'Penghuni', 'CSV • semua', () => exportFile('occupants')),
          ], wideCols: 2),
          if (d['demo'] != null && d['demo']['enabled'] == true) ...[
            const SectionTitle('Mode demo: geser waktu'),
            Panel(
              color: kInfo.withAlpha(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const IconBadge(Icons.schedule, color: kInfo, size: 40),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Tanggal aplikasi: ${fd(d['demo']['today'])}${(d['demo']['offset'] as num) != 0 ? ' (${(d['demo']['offset'] as num) > 0 ? '+' : ''}${d['demo']['offset']} hari)' : ' (waktu nyata)'}', style: const TextStyle(fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 10),
                const Text('Maju ke depan menjalankan rutinitas harian pada setiap hari yang dilewati (tagihan terbit, pengingat, denda bertambah). Mundur hanya mengubah tanggal dan tidak membatalkan data yang sudah terbentuk.', style: TextStyle(fontSize: 12, color: kMuted, height: 1.5)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton(onPressed: () => shift(days: 1), child: const Text('+1 hari')),
                  OutlinedButton(onPressed: () => shift(days: 7), child: const Text('+7 hari')),
                  OutlinedButton(onPressed: () => shift(days: 30), child: const Text('+30 hari')),
                  TextButton(onPressed: () => shift(reset: true), child: const Text('Kembali ke waktu nyata')),
                ]),
              ]),
            ),
          ],
        ], padding: const EdgeInsets.fromLTRB(16, 4, 16, 28));
      },
    );
  }
}

// ---------------------------------------------------------------- Unit & penghuni
class UnitsTab extends StatelessWidget {
  final int aptId;
  final String role;
  final List<String> mods;
  const UnitsTab({super.key, required this.aptId, required this.role, required this.mods});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Column(children: [
          const TabBar(tabs: [Tab(text: 'Unit'), Tab(text: 'Penghuni'), Tab(text: 'Permintaan')]),
          Expanded(child: TabBarView(children: [UnitsList(aptId: aptId, role: role), OccupantsList(aptId: aptId), RequestsList(aptId: aptId, mods: mods)])),
        ]),
      );
}

Future<List<List<String>>> typeOptions(int aptId) async {
  final t = (await Api.get('/apartments/$aptId/unit-types') as List).cast<Map>();
  return [for (final x in t) ['${x['id']}', '${x['name']}']];
}

Future<void> showInviteCode(BuildContext c, Map inv) => showDialog<void>(
      context: c,
      builder: (_) => AlertDialog(
        title: const Text('Kode undangan dibuat'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SelectableText('${inv['code']}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontFamily: 'monospace')),
          const SizedBox(height: 8),
          Text('Unit ${inv['unit']?['number'] ?? ''} • berlaku sampai ${fd(inv['expires_at'])}\nKode sekali pakai. Bagikan ke calon penghuni.', textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: '${inv['code']}')); if (c.mounted) toast(c, 'Kode disalin.'); }, child: const Text('Salin')),
          FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Selesai')),
        ],
      ),
    );

class UnitsList extends StatefulWidget {
  final int aptId;
  final String role;
  const UnitsList({super.key, required this.aptId, required this.role});
  @override
  State<UnitsList> createState() => _UnitsListState();
}

class _UnitsListState extends State<UnitsList> {
  String filter = 'all';
  String q = '';
  int tick = 0;

  Future<void> _add(BuildContext c, Future<void> Function() reload) async {
    final opts = await guard(c, () => typeOptions(widget.aptId));
    if (opts == null || !c.mounted) return;
    final f = await showForm(c, title: 'Tambah unit', initial: {'floor': 1, 'status': 'available'}, fields: [
      const Field('number', 'Nomor unit', required: true, hint: 'contoh: A-101'),
      const Field('building', 'Gedung (opsional)'),
      const Field('floor', 'Lantai', type: 'number', required: true),
      Field('unit_type_id', 'Tipe unit', type: 'select', required: true, options: opts),
      const Field('status', 'Status', type: 'select', options: [['available', 'Tersedia'], ['maintenance', 'Tidak tersedia (perbaikan)']]),
    ]);
    if (f == null || !c.mounted) return;
    if (await guard(c, () => Api.post('/apartments/${widget.aptId}/units', f), ok: 'Unit ditambahkan.') != null) await reload();
  }

  Future<void> _tap(BuildContext c, Map u, Future<void> Function() reload) async {
    final occ = (u['occupancies'] as List).cast<Map>();
    final type = u['type'] as Map;
    final i = await actionSheet(c, 'Unit ${u['number']}', const [(Icons.vpn_key_outlined, 'Buat undangan penghuni'), (Icons.edit_outlined, 'Ubah unit'), (Icons.delete_outline, 'Hapus unit')]);
    if (i == null || !c.mounted) return;
    if (i == 0) {
      if (u['status'] == 'maintenance') return toast(c, 'Unit sedang tidak tersedia.', error: true);
      if (occ.length >= (type['capacity'] as num)) return toast(c, 'Unit sudah mencapai kapasitas penghuni.', error: true);
      final f = await showForm(c, title: 'Undang penghuni — ${u['number']}', submit: 'Buat kode', initial: {
        'is_primary': !occ.any((o) => o['is_primary'] == true),
        'start_date': DateTime.now().toIso8601String().substring(0, 10),
        'deposit': type['rent_price'],
        'days_valid': 14,
      }, fields: const [
        Field('is_primary', 'Penghuni utama (penanggung tagihan)', type: 'switch'),
        Field('start_date', 'Tanggal mulai tinggal', type: 'date'),
        Field('end_date', 'Tanggal berakhir kontrak', type: 'date'),
        Field('deposit', 'Deposit (Rp)', type: 'number'),
        Field('days_valid', 'Kode berlaku (hari)', type: 'number'),
      ]);
      if (f == null || !c.mounted) return;
      final inv = await guard(c, () => Api.post('/apartments/${widget.aptId}/invites', {...f, 'unit_id': u['id']}));
      if (inv != null && c.mounted) await showInviteCode(c, inv as Map);
    } else if (i == 1) {
      final opts = await guard(c, () => typeOptions(widget.aptId));
      if (opts == null || !c.mounted) return;
      final f = await showForm(c, title: 'Ubah unit', initial: {...u, 'unit_type_id': '${u['unit_type_id']}'}, fields: [
        const Field('number', 'Nomor unit', required: true),
        const Field('building', 'Gedung (opsional)'),
        const Field('floor', 'Lantai', type: 'number', required: true),
        Field('unit_type_id', 'Tipe unit', type: 'select', required: true, options: opts),
        if (occ.isEmpty) const Field('status', 'Status', type: 'select', options: [['available', 'Tersedia'], ['maintenance', 'Tidak tersedia (perbaikan)']]),
      ]);
      if (f == null || !c.mounted) return;
      if (await guard(c, () => Api.put('/apartments/${widget.aptId}/units/${u['id']}', f), ok: 'Unit diperbarui.') != null) await reload();
    } else {
      if (!await confirmDlg(c, 'Hapus unit ${u['number']}?', 'Unit yang memiliki riwayat penghuni atau tagihan tidak dapat dihapus.', ok: 'Hapus')) return;
      if (!c.mounted) return;
      if (await guard(c, () => Api.delete('/apartments/${widget.aptId}/units/${u['id']}'), ok: 'Unit dihapus.') != null) await reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader(
      key: ValueKey(tick),
      load: () => Api.get('/apartments/${widget.aptId}/units'),
      builder: (c, data, reload) {
        var list = (data as List).cast<Map>();
        if (filter != 'all') list = list.where((u) => u['status'] == filter).toList();
        if (q.trim().isNotEmpty) {
          final k = q.trim().toLowerCase();
          list = list.where((u) => '${u['number']} ${u['building'] ?? ''} ${u['type']?['name'] ?? ''} ${(u['occupancies'] as List).map((o) => o['user']?['name']).join(' ')}'.toLowerCase().contains(k)).toList();
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(onPressed: () => _add(c, reload), icon: const Icon(Icons.add), label: const Text('Unit')),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(onChanged: (v) => setState(() => q = v), decoration: deco('Cari unit, tipe, atau nama penghuni', prefix: const Icon(Icons.search))),
            ),
            ChipsBar(const [['all', 'Semua'], ['available', 'Tersedia'], ['occupied', 'Terisi'], ['maintenance', 'Tidak tersedia']], filter, (v) => setState(() => filter = v)),
            Expanded(
              child: refreshList(reload, [
                Panel(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UnitTypesPage(aptId: widget.aptId, canEdit: widget.role == 'owner'))).then((_) => setState(() => tick++)),
                  child: Row(children: [const Icon(Icons.category_outlined, color: kPine), const SizedBox(width: 10), const Expanded(child: Text('Kelola tipe unit', style: TextStyle(fontWeight: FontWeight.w600))), if (widget.role != 'owner') const Text('lihat', style: TextStyle(color: kMuted, fontSize: 12)), const Icon(Icons.chevron_right, color: kMuted)]),
                ),
                if (list.isEmpty) const Empty(Icons.meeting_room_outlined, 'Belum ada unit', 'Tambahkan unit dengan tombol di bawah.'),
                for (final u in list)
                  Panel(
                    onTap: () => _tap(c, u, reload),
                    child: Row(children: [
                      Container(
                        width: 62,
                        height: 46,
                        margin: const EdgeInsets.only(right: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: statusInfo('${u['status']}').$2.withAlpha(28), borderRadius: BorderRadius.circular(14)),
                        child: Text('${u['number']}', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: statusInfo('${u['status']}').$2)),
                      ),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${u['building'] != null ? '${u['building']} • ' : ''}${u['type']?['name']} • Lantai ${u['floor']}', style: const TextStyle(fontSize: 13)),
                        Text((u['occupancies'] as List).isEmpty ? rp(u['type']?['rent_price']) + '/bulan' : (u['occupancies'] as List).map((o) => '${o['user']?['name']}').join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 12)),
                      ])),
                      Pill.status('${u['status']}'),
                    ]),
                  ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class OccupantsList extends StatelessWidget {
  final int aptId;
  const OccupantsList({super.key, required this.aptId});

  Future<void> _place(BuildContext c, Future<void> Function() reload) async {
    final raw = await guard(c, () => Api.get('/apartments/$aptId/units'));
    if (raw == null || !c.mounted) return;
    final units = (raw as List).cast<Map>().where((u) => u['status'] != 'maintenance' && (u['occupancies'] as List).length < (u['type']['capacity'] as num)).toList();
    if (units.isEmpty) return toast(c, 'Tidak ada unit yang masih dapat dihuni.', error: true);
    final f = await showForm(c, title: 'Daftarkan penghuni', submit: 'Daftarkan', initial: {'is_primary': true, 'start_date': DateTime.now().toIso8601String().substring(0, 10), 'deposit': 0}, fields: [
      const Field('email', 'Email akun penghuni (sudah terdaftar)', required: true),
      Field('unit_id', 'Unit', type: 'select', required: true, options: [for (final u in units) ['${u['id']}', 'Unit ${u['number']} — ${u['type']['name']} (${(u['occupancies'] as List).length}/${u['type']['capacity']})']]),
      const Field('is_primary', 'Penghuni utama (penanggung tagihan)', type: 'switch'),
      const Field('start_date', 'Tanggal mulai tinggal', type: 'date'),
      const Field('end_date', 'Tanggal berakhir kontrak', type: 'date'),
      const Field('deposit', 'Deposit (Rp)', type: 'number'),
    ]);
    if (f == null || !c.mounted) return;
    if (await guard(c, () => Api.post('/apartments/$aptId/occupancies', f), ok: 'Penghuni didaftarkan.') != null) await reload();
  }

  Future<void> _tap(BuildContext c, Map o, Future<void> Function() reload) async {
    final i = await actionSheet(c, '${o['user']?['name']} • ${o['unit']?['number']}', const [(Icons.edit_calendar_outlined, 'Ubah masa sewa & deposit'), (Icons.logout, 'Akhiri masa tinggal')]);
    if (i == null || !c.mounted) return;
    if (i == 0) {
      final f = await showForm(c, title: 'Masa sewa', initial: o.cast<String, dynamic>(), fields: const [
        Field('start_date', 'Tanggal mulai', type: 'date'),
        Field('end_date', 'Tanggal berakhir', type: 'date'),
        Field('deposit', 'Deposit (Rp)', type: 'number'),
      ]);
      if (f == null || !c.mounted) return;
      if (await guard(c, () => Api.put('/apartments/$aptId/occupancies/${o['id']}', f), ok: 'Data penempatan diperbarui.') != null) await reload();
    } else {
      if (!await confirmDlg(c, 'Akhiri masa tinggal?', '${o['user']?['name']} tidak lagi menjadi penghuni unit ${o['unit']?['number']}. Riwayat pembayaran tetap tersimpan.', ok: 'Akhiri')) return;
      if (!c.mounted) return;
      try {
        await Api.post('/apartments/$aptId/occupancies/${o['id']}/end');
        if (c.mounted) toast(c, 'Masa tinggal diakhiri.');
        await reload();
      } on ApiError catch (e) {
        if (!c.mounted) return;
        if (e.code == 409) {
          if (await confirmDlg(c, 'Masih ada tunggakan', '${e.message}\n\nTetap akhiri masa tinggal?', ok: 'Tetap akhiri') && c.mounted) {
            if (await guard(c, () => Api.post('/apartments/$aptId/occupancies/${o['id']}/end', {'force': true}), ok: 'Masa tinggal diakhiri.') != null) await reload();
          }
        } else {
          toast(c, e.message, error: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Loader(
        load: () => Api.get('/apartments/$aptId/occupancies'),
        builder: (c, data, reload) {
          final list = (data as List).cast<Map>();
          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton.extended(onPressed: () => _place(c, reload), icon: const Icon(Icons.person_add_alt), label: const Text('Penghuni')),
            body: refreshList(reload, [
              if (list.isEmpty) const Empty(Icons.people_outline, 'Belum ada penghuni aktif', 'Daftarkan langsung dengan tombol di bawah, atau buat kode undangan dari tab Unit.'),
              for (final o in list)
                Panel(
                  onTap: () => _tap(c, o, reload),
                  child: Row(children: [
                    Avatar(o['user']?['photo_url'] as String?, '${o['user']?['name']}', radius: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${o['user']?['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('Unit ${o['unit']?['number']} • ${o['unit']?['type']?['name'] ?? ''} • ${o['user']?['phone'] ?? ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
                      Text('${fd(o['start_date'])} – ${fd(o['end_date'])} • deposit ${rp(o['deposit'])}', style: const TextStyle(color: kMuted, fontSize: 12)),
                    ])),
                    Pill(o['is_primary'] == true ? 'Utama' : 'Tambahan', o['is_primary'] == true ? kPine : kInfo),
                  ]),
                ),
            ]),
          );
        },
      );
}

class RequestsList extends StatelessWidget {
  final int aptId;
  final List<String> mods;
  const RequestsList({super.key, required this.aptId, required this.mods});

  Future<dynamic> _load() async {
    final r = await Future.wait([
      Api.get('/apartments/$aptId/join-requests'),
      Api.get('/apartments/$aptId/invites'),
      if (mods.contains('move_out')) Api.get('/apartments/$aptId/move-out') else Future.value([]),
    ]);
    return {'req': r[0], 'inv': r[1], 'out': r[2]};
  }

  Future<void> _decide(BuildContext c, Map r, bool approve, Future<void> Function() reload) async {
    Map<String, dynamic> body = {'approve': approve};
    if (approve) {
      if (r['invite_id'] == null) {
        final f = await showForm(c, title: 'Terima ${r['user']?['name']} — unit ${r['unit']?['number']}', submit: 'Terima', initial: {'start_date': DateTime.now().toIso8601String().substring(0, 10), 'deposit': 0}, fields: const [
          Field('start_date', 'Tanggal mulai tinggal', type: 'date'),
          Field('end_date', 'Tanggal berakhir kontrak', type: 'date'),
          Field('deposit', 'Deposit (Rp)', type: 'number'),
        ]);
        if (f == null) return;
        body = {'approve': true, ...f};
      } else if (!await confirmDlg(c, 'Terima penghuni?', '${r['user']?['name']} akan menjadi penghuni unit ${r['unit']?['number']}.', ok: 'Terima')) {
        return;
      }
    } else {
      final f = await showForm(c, title: 'Tolak permintaan', submit: 'Tolak', fields: const [Field('reason', 'Alasan penolakan', type: 'multiline', required: true)]);
      if (f == null) return;
      body = {'approve': false, ...f};
    }
    if (!c.mounted) return;
    if (await guard(c, () => Api.post('/apartments/$aptId/join-requests/${r['id']}/decide', body), ok: approve ? 'Penghuni diterima.' : 'Permintaan ditolak.') != null) await reload();
  }

  Future<void> _decideOut(BuildContext c, Map r, bool approve, Future<void> Function() reload) async {
    Map<String, dynamic> body = {'approve': approve};
    if (approve) {
      if (!await confirmDlg(c, 'Setujui permintaan keluar?', 'Tanggal keluar ${fd(r['desired_date'])} akan dicatat. Akhiri masa tinggal dari tab Penghuni saat penghuni keluar.', ok: 'Setujui')) return;
    } else {
      final f = await showForm(c, title: 'Tolak permintaan keluar', submit: 'Tolak', fields: const [Field('note', 'Alasan penolakan', type: 'multiline', required: true)]);
      if (f == null) return;
      body = {'approve': false, ...f};
    }
    if (!c.mounted) return;
    if (await guard(c, () => Api.post('/apartments/$aptId/move-out/${r['id']}/decide', body), ok: 'Keputusan disimpan.') != null) await reload();
  }

  Widget _buttons(VoidCallback no, VoidCallback yes, String yesLabel) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          Expanded(child: OutlinedButton(onPressed: no, child: const Text('Tolak'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: yes, child: Text(yesLabel))),
        ]),
      );

  @override
  Widget build(BuildContext context) => Loader(
        load: _load,
        builder: (c, d, reload) {
          final reqs = (d['req'] as List).cast<Map>();
          final invs = (d['inv'] as List).cast<Map>();
          final outs = (d['out'] as List).cast<Map>();
          return refreshList(reload, [
            const SectionTitle('Permintaan bergabung'),
            if (reqs.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Belum ada permintaan.', style: TextStyle(color: kMuted))),
            for (final r in reqs)
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${r['user']?['name']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    Pill.status('${r['status']}'),
                  ]),
                  Text('Unit ${r['unit']?['number']} • ${r['user']?['phone'] ?? ''} • ${r['is_primary'] == true ? 'penghuni utama' : 'penghuni tambahan'}', style: const TextStyle(color: kMuted, fontSize: 12)),
                  Text('Mulai ${fd(r['start_date'])} • deposit ${rp(r['deposit'])}', style: const TextStyle(color: kMuted, fontSize: 12)),
                  if (r['reject_reason'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Alasan: ${r['reject_reason']}', style: const TextStyle(color: kBad, fontSize: 12))),
                  if (r['status'] == 'pending') _buttons(() => _decide(c, r, false, reload), () => _decide(c, r, true, reload), 'Terima'),
                ]),
              ),
            const SectionTitle('Kode undangan'),
            if (invs.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Belum ada undangan. Buat dari tab Unit.', style: TextStyle(color: kMuted))),
            for (final i in invs)
              Panel(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: '${i['code']}'));
                  if (c.mounted) toast(c, 'Kode ${i['code']} disalin.');
                },
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i['code']}', style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'monospace', letterSpacing: 1)),
                    Text('Unit ${i['unit']?['number']} • berlaku sampai ${fd(i['expires_at'])}', style: const TextStyle(color: kMuted, fontSize: 12)),
                  ])),
                  if (i['used_at'] != null) const Pill('Terpakai', kMuted) else if ((pd(i['expires_at']) ?? DateTime.now().add(const Duration(days: 1))).isBefore(DateTime.now())) const Pill('Kedaluwarsa', kBad) else const Pill('Aktif', kOk),
                ]),
              ),
            if (mods.contains('move_out')) ...[
              const SectionTitle('Permintaan keluar'),
              if (outs.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Belum ada permintaan keluar.', style: TextStyle(color: kMuted))),
              for (final r in outs)
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${r['user']?['name']} • ${r['occupancy']?['unit']?['number'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      Pill.status('${r['status']}'),
                    ]),
                    Text('Rencana keluar ${fd(r['desired_date'])}', style: const TextStyle(color: kMuted, fontSize: 12)),
                    if (r['reason'] != null) Text('${r['reason']}', style: const TextStyle(fontSize: 13)),
                    if (r['note'] != null) Text('Catatan: ${r['note']}', style: const TextStyle(color: kMuted, fontSize: 12)),
                    if (r['status'] == 'pending') _buttons(() => _decideOut(c, r, false, reload), () => _decideOut(c, r, true, reload), 'Setujui'),
                  ]),
                ),
            ],
          ]);
        },
      );
}

// ---------------------------------------------------------------- Keuangan
class FinanceTab extends StatelessWidget {
  final int aptId;
  final List<String> mods;
  const FinanceTab({super.key, required this.aptId, required this.mods});
  @override
  Widget build(BuildContext context) {
    final tabs = <(String, Widget)>[
      ('Tagihan', BillsAdmin(aptId: aptId)),
      if (mods.contains('fines')) ('Denda', FinesAdmin(aptId: aptId)),
      ('Pembayaran', PaymentsAdmin(aptId: aptId)),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Column(children: [
        TabBar(tabs: [for (final t in tabs) Tab(text: t.$1)]),
        Expanded(child: TabBarView(children: [for (final t in tabs) t.$2])),
      ]),
    );
  }
}

class BillsAdmin extends StatefulWidget {
  final int aptId;
  const BillsAdmin({super.key, required this.aptId});
  @override
  State<BillsAdmin> createState() => _BillsAdminState();
}

class _BillsAdminState extends State<BillsAdmin> {
  String filter = 'unpaid';

  Map<String, dynamic>? get _q => switch (filter) {
        'unpaid' => {'status': 'unpaid'},
        'overdue' => {'overdue': 1},
        'paid' => {'status': 'paid'},
        _ => null,
      };

  Future<void> _special(BuildContext c, Future<void> Function() reload) async {
    final occ = await guard(c, () => Api.get('/apartments/${widget.aptId}/occupancies'));
    if (occ == null || !c.mounted) return;
    final opts = [
      for (final o in (occ as List).cast<Map>()) if (o['is_primary'] == true) ['${o['id']}', 'Unit ${o['unit']?['number']} — ${o['user']?['name']}'],
    ];
    if (opts.isEmpty) return toast(c, 'Belum ada penghuni utama aktif.', error: true);
    final f = await showForm(c, title: 'Tagihan khusus', submit: 'Terbitkan', fields: [
      Field('occupancy_id', 'Penghuni (utama)', type: 'select', required: true, options: opts),
      const Field('label', 'Keterangan biaya', required: true, hint: 'mis. Ganti kartu akses hilang'),
      const Field('amount', 'Nominal (Rp)', type: 'number', required: true),
      const Field('due_date', 'Jatuh tempo (default 7 hari)', type: 'date'),
    ]);
    if (f == null || !c.mounted) return;
    if (await guard(c, () => Api.post('/apartments/${widget.aptId}/bills', f), ok: 'Tagihan khusus diterbitkan.') != null) await reload();
  }

  @override
  Widget build(BuildContext context) => Loader(
        key: ValueKey(filter),
        load: () => Api.get('/apartments/${widget.aptId}/bills', q: _q),
        builder: (c, data, reload) {
          final list = (data as List).cast<Map>();
          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton.extended(onPressed: () => _special(c, reload), icon: const Icon(Icons.add), label: const Text('Tagihan khusus')),
            body: Column(children: [
              ChipsBar(const [['unpaid', 'Belum lunas'], ['overdue', 'Terlambat'], ['paid', 'Lunas'], ['all', 'Semua']], filter, (v) => setState(() => filter = v)),
              Expanded(
                child: refreshList(reload, [
                  if (list.isEmpty) const Empty(Icons.receipt_long_outlined, 'Tidak ada tagihan'),
                  for (final b in list)
                    Panel(
                      onTap: () => infoDlg(c, '${b['label']}', Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        InfoRow('Unit', '${b['unit']?['number']}'),
                        InfoRow('Penghuni', '${b['user']?['name']}'),
                        InfoRow('Terbit', fd(b['issued_on'])),
                        InfoRow('Jatuh tempo', fd(b['due_date'])),
                        if (b['paid_at'] != null) InfoRow('Dibayar', fdt(b['paid_at'])),
                        const Divider(),
                        for (final it in (b['items'] as List).cast<Map>()) InfoRow('${it['label']}', rp(it['amount'])),
                        const Divider(),
                        InfoRow('Total', rp(b['total'])),
                      ])),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${b['label']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('Unit ${b['unit']?['number']} • ${b['user']?['name']} • jatuh tempo ${fd(b['due_date'])}', style: const TextStyle(color: kMuted, fontSize: 12)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(rp(b['total']), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          b['is_overdue'] == true ? Pill('Terlambat ${b['days_late']} hr', kBad) : Pill.status('${b['status']}'),
                        ]),
                      ]),
                    ),
                ]),
              ),
            ]),
          );
        },
      );
}

class FinesAdmin extends StatefulWidget {
  final int aptId;
  const FinesAdmin({super.key, required this.aptId});
  @override
  State<FinesAdmin> createState() => _FinesAdminState();
}

class _FinesAdminState extends State<FinesAdmin> {
  String filter = 'open';

  Future<void> _tap(BuildContext c, Map f, Future<void> Function() reload) async {
    if (f['status'] != 'running' && f['status'] != 'due') return;
    final i = await actionSheet(c, 'Denda unit ${f['unit']?['number']}', const [(Icons.volunteer_activism_outlined, 'Bebaskan denda'), (Icons.edit_outlined, 'Ubah nominal denda')]);
    if (i == null || !c.mounted) return;
    Map<String, dynamic>? body;
    if (i == 0) {
      final r = await showForm(c, title: 'Bebaskan denda', submit: 'Bebaskan', fields: const [Field('reason', 'Alasan pembebasan', type: 'multiline', required: true)]);
      if (r != null) body = {'action': 'waive', ...r};
    } else {
      final r = await showForm(c, title: 'Ubah nominal denda', initial: {'amount': f['amount']}, fields: const [Field('amount', 'Nominal baru (Rp)', type: 'number', required: true), Field('reason', 'Catatan')]);
      if (r != null) body = {'action': 'set', ...r};
    }
    if (body == null || !c.mounted) return;
    if (await guard(c, () => Api.post('/apartments/${widget.aptId}/fines/${f['id']}/adjust', body), ok: 'Denda diperbarui.') != null) await reload();
  }

  @override
  Widget build(BuildContext context) => Loader(
        key: ValueKey(filter),
        load: () => Api.get('/apartments/${widget.aptId}/fines', q: filter == 'open' ? {'status': 'open'} : null),
        builder: (c, data, reload) {
          final list = (data as List).cast<Map>();
          return Column(children: [
            ChipsBar(const [['open', 'Belum selesai'], ['all', 'Semua']], filter, (v) => setState(() => filter = v)),
            Expanded(
              child: refreshList(reload, [
                if (list.isEmpty) const Empty(Icons.verified_outlined, 'Tidak ada denda'),
                for (final f in list)
                  Panel(
                    onTap: () => _tap(c, f, reload),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Unit ${f['unit']?['number']} • ${f['user']?['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${f['days']} hari • mulai ${fd(f['started_on'])}${f['waive_reason'] != null ? ' • ${f['waive_reason']}' : ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(rp(f['amount']), style: const TextStyle(fontWeight: FontWeight.w800, color: kBad)),
                        const SizedBox(height: 4),
                        Pill.status('${f['status']}'),
                      ]),
                    ]),
                  ),
              ]),
            ),
          ]);
        },
      );
}

class PaymentsAdmin extends StatelessWidget {
  final int aptId;
  const PaymentsAdmin({super.key, required this.aptId});
  @override
  Widget build(BuildContext context) => Loader(
        load: () => Api.get('/apartments/$aptId/payments'),
        builder: (c, data, reload) {
          final list = (data as List).cast<Map>();
          return refreshList(reload, [
            if (list.isEmpty) const Empty(Icons.receipt_long_outlined, 'Belum ada pembayaran'),
            for (final p in list)
              Panel(
                onTap: () => showReceipt(c, aptId, p['id'] as int),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Unit ${p['unit']?['number'] ?? '-'} • ${p['user']?['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${p['receipt_no']} • ${fdt(p['paid_at'])} • ${p['method']}', style: const TextStyle(color: kMuted, fontSize: 12)),
                  ])),
                  Text(rp(p['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
          ]);
        },
      );
}

// ---------------------------------------------------------------- Lainnya
class MoreTab extends StatelessWidget {
  final int aptId;
  final Map apt;
  final String role;
  final List<String> mods;
  final Future<void> Function() onChanged;
  const MoreTab({super.key, required this.aptId, required this.apt, required this.role, required this.mods, required this.onChanged});

  Widget _t(BuildContext c, IconData i, String title, String sub, Widget page) => Panel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(i, color: kPine),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)).then((_) => onChanged()),
        ),
      );

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        if (mods.contains('announcements')) _t(context, Icons.campaign_outlined, 'Pengumuman', 'Kirim informasi ke seluruh penghuni', _Scaffolded('Pengumuman', AnnouncementsList(aptId: aptId, canEdit: true))),
        if (mods.contains('facilities')) _t(context, Icons.pool_outlined, 'Fasilitas bersama', 'Kolam, gym, parkir, dan lainnya', _Scaffolded('Fasilitas bersama', FacilitiesList(aptId: aptId, canEdit: true))),
        if (mods.contains('services')) _t(context, Icons.room_service_outlined, 'Layanan tambahan', 'Gym, sarapan, parkir — ditagihkan akhir bulan', ServicesPage(aptId: aptId)),
        _t(context, Icons.category_outlined, 'Tipe unit', role == 'owner' ? 'Kelola tipe, harga sewa, dan kapasitas' : 'Lihat tipe dan harga sewa', UnitTypesPage(aptId: aptId, canEdit: role == 'owner')),
        if (role == 'owner') _t(context, Icons.admin_panel_settings_outlined, 'Admin apartemen', 'Tambah atau nonaktifkan admin', AdminsPage(aptId: aptId)),
        _t(context, Icons.settings_outlined, 'Pengaturan apartemen', role == 'owner' ? 'Informasi, biaya, jadwal tagihan, dan fitur' : 'Informasi, peraturan, dan denda', SettingsPage(aptId: aptId, role: role)),
        _t(context, Icons.notifications_none, 'Notifikasi', 'Aktivitas terbaru', NotificationsPage(aptId: aptId)),
        _t(context, Icons.person_outline, 'Profil & akun', 'Ubah data dan kata sandi', const ProfilePage()),
        Panel(
          onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
          child: const Row(children: [Icon(Icons.swap_horiz, color: kMuted), SizedBox(width: 12), Text('Ganti apartemen', style: TextStyle(fontWeight: FontWeight.w600))]),
        ),
      ]);
}

class _Scaffolded extends StatelessWidget {
  final String title;
  final Widget body;
  const _Scaffolded(this.title, this.body);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: appBarOf(title), body: body);
}
