import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';
import 'common.dart';

class TenantShell extends StatefulWidget {
  final int aptId;
  final String aptName;
  const TenantShell({super.key, required this.aptId, required this.aptName});
  @override
  State<TenantShell> createState() => _TenantShellState();
}

class _TenantShellState extends State<TenantShell> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    return Loader(
      load: () => Api.get('/apartments/${widget.aptId}'),
      builder: (c, apt, reload) {
        final mods = (apt['modules'] as List).cast<String>();
        final id = widget.aptId;
        final tabs = <(String, IconData, Widget)>[
          ('Beranda', Icons.home_outlined, TenantHome(aptId: id, goTab: (i) => setState(() => idx = i))),
          ('Pembayaran', Icons.receipt_long_outlined, PayTab(aptId: id)),
          if (mods.contains('reports')) ('Laporan', Icons.build_circle_outlined, ReportsPage(aptId: id, staff: false)),
          ('Info', Icons.campaign_outlined, TenantInfo(aptId: id, apt: apt, mods: mods)),
          ('Profil', Icons.person_outline, ProfileBody(aptId: id, moveOut: mods.contains('move_out'))),
        ];
        if (idx >= tabs.length) idx = 0;
        return Scaffold(
          appBar: appBarOf(widget.aptName, actions: [
            NotifBell(aptId: id),
          ]),
          body: KeyedSubtree(key: ValueKey('tab$idx'), child: tabs[idx].$3),
          bottomNavigationBar: NavigationBar(
            selectedIndex: idx,
            onDestinationSelected: (i) => setState(() => idx = i),
            destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.$2), label: t.$1)],
          ),
        );
      },
    );
  }
}

class TenantHome extends StatelessWidget {
  final int aptId;
  final void Function(int) goTab;
  const TenantHome({super.key, required this.aptId, required this.goTab});

  @override
  Widget build(BuildContext context) {
    return Loader(
      load: () => Api.get('/apartments/$aptId/dashboard'),
      builder: (c, d, reload) {
        final occ = d['occupancy'] as Map?;
        final unit = occ?['unit'] as Map?;
        final type = unit?['type'] as Map?;
        final bills = (d['unpaid_bills'] as List).cast<Map>();
        final fines = (d['fines'] as List).cast<Map>();
        final anns = (d['announcements'] as List).cast<Map>();
        final mates = (d['housemates'] as List).cast<Map>();
        final payable = (d['payable_total'] ?? 0) as num;
        final overdue = bills.where((b) => b['is_overdue'] == true).length;
        return refreshList(reload, [
          if (d['demo'] != null && (d['demo']['offset'] as num) != 0)
            Panel(color: kInfo.withAlpha(20), child: Row(children: [const Icon(Icons.schedule, color: kInfo), const SizedBox(width: 10), Expanded(child: Text('Waktu demo aktif: ${fd(d['demo']['today'])}', style: const TextStyle(color: kInfo, fontWeight: FontWeight.w600)))])),
          if (occ == null)
            const Empty(Icons.meeting_room_outlined, 'Anda belum memiliki unit aktif', 'Hubungi pengelola apartemen.')
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: kPine, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Unit ${unit?['number']}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text(occ['is_primary'] == true ? 'Penghuni utama' : 'Penghuni tambahan', style: const TextStyle(color: Colors.white, fontSize: 12))),
                ]),
                const SizedBox(height: 2),
                Text('${type?['name'] ?? ''} • Lantai ${unit?['floor']}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _lease('Mulai', fd(occ['start_date']))),
                  Expanded(child: _lease('Berakhir', fd(occ['end_date']))),
                  Expanded(child: _lease('Deposit', rp(occ['deposit']))),
                ]),
                if (mates.length > 1) ...[
                  const SizedBox(height: 12),
                  Text('Penghuni unit: ${mates.map((m) => '${m['name']}${m['is_me'] == true ? ' (Anda)' : ''}').join(', ')}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ]),
            ),
          const SizedBox(height: 12),
          Panel(
            onTap: () => goTab(1),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Perlu dibayar', style: TextStyle(color: kMuted, fontSize: 13)),
                const SizedBox(height: 2),
                Text(rp(payable), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: payable > 0 ? kInk : kOk)),
                const SizedBox(height: 2),
                Text(bills.isEmpty && fines.isEmpty ? 'Semua tagihan sudah lunas.' : '${bills.length} tagihan${overdue > 0 ? ' • $overdue terlambat' : ''}${fines.isNotEmpty ? ' • denda berjalan' : ''}', style: TextStyle(color: overdue > 0 || fines.isNotEmpty ? kBad : kMuted, fontSize: 12)),
              ])),
              const Icon(Icons.chevron_right, color: kMuted),
            ]),
          ),
          if (fines.isNotEmpty)
            Panel(
              color: kBad.withAlpha(14),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: kBad),
                const SizedBox(width: 10),
                Expanded(child: Text('Denda keterlambatan ${rp(fines.fold<num>(0, (s, f) => s + (f['amount'] as num)))} (${fines.first['days']} hari). Lunasi tagihan jatuh tempo untuk menghentikan denda.', style: const TextStyle(color: kBad, fontSize: 13))),
              ]),
            ),
          if (bills.isNotEmpty) const SectionTitle('Tagihan terdekat'),
          for (final b in bills.take(3))
            Panel(
              onTap: () => goTab(1),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${b['label']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Jatuh tempo ${fd(b['due_date'])}', style: const TextStyle(color: kMuted, fontSize: 12)),
                ])),
                Text(rp(b['total']), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          if (anns.isNotEmpty) const SectionTitle('Pengumuman terbaru'),
          for (final a in anns)
            Panel(
              onTap: () => infoDlg(context, '${a['title']}', Text('${a['body']}')),
              child: Row(children: [
                if (a['is_pinned'] == true) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.push_pin, size: 16, color: kBrass)),
                Expanded(child: Text('${a['title']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(fd(a['created_at']), style: const TextStyle(color: kMuted, fontSize: 12)),
              ]),
            ),
          if (((d['open_reports'] ?? 0) as num) > 0)
            Panel(
              onTap: () => goTab(2),
              child: Row(children: [
                const Icon(Icons.build_circle_outlined, color: kBrass),
                const SizedBox(width: 10),
                Expanded(child: Text('${d['open_reports']} laporan Anda masih diproses')),
                const Icon(Icons.chevron_right, color: kMuted),
              ]),
            ),
        ], padding: const EdgeInsets.fromLTRB(16, 8, 16, 24));
      },
    );
  }

  Widget _lease(String l, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 2),
        Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ]);
}

// ---------------------------------------------------------------- Pembayaran
class PayTab extends StatefulWidget {
  final int aptId;
  const PayTab({super.key, required this.aptId});
  @override
  State<PayTab> createState() => _PayTabState();
}

class _PayTabState extends State<PayTab> {
  final Set<String> sel = {};

  Future<dynamic> _load() async {
    final r = await Future.wait([
      Api.get('/apartments/${widget.aptId}/bills', q: {'status': 'unpaid'}),
      Api.get('/apartments/${widget.aptId}/fines', q: {'status': 'open'}),
      Api.get('/apartments/${widget.aptId}/payments'),
    ]);
    return {'bills': r[0], 'fines': r[1], 'payments': r[2]};
  }

  bool _mine(Map b) => b['payable'] == true && b['user_id'] == Session.uid;

  Future<void> _pay(BuildContext c, List<Map> bills, List<Map> fines, Future<void> Function() reload) async {
    num total = 0;
    final items = <Map<String, dynamic>>[];
    for (final b in bills) {
      if (sel.contains('bill:${b['id']}')) {
        total += b['total'] as num;
        items.add({'type': 'bill', 'id': b['id']});
      }
    }
    for (final f in fines) {
      if (sel.contains('fine:${f['id']}')) {
        total += f['amount'] as num;
        items.add({'type': 'fine', 'id': f['id']});
      }
    }
    const methods = ['Transfer Bank', 'QRIS', 'Virtual Account', 'E-Wallet'];
    final i = await actionSheet(c, 'Metode pembayaran • ${rp(total)}', [
      (Icons.account_balance_outlined, methods[0]),
      (Icons.qr_code_2, methods[1]),
      (Icons.credit_card, methods[2]),
      (Icons.account_balance_wallet_outlined, methods[3]),
    ]);
    if (i == null || !c.mounted) return;
    final ok = await confirmDlg(c, 'Konfirmasi pembayaran', 'Bayar ${rp(total)} dengan ${methods[i]}?\n\nIni adalah simulasi: tidak ada uang sungguhan yang berpindah.', ok: 'Bayar sekarang');
    if (!ok || !c.mounted) return;
    final p = await guard(c, () => Api.post('/apartments/${widget.aptId}/payments', {'method': methods[i], 'items': items}));
    if (p == null) {
      await reload();
      return;
    }
    setState(sel.clear);
    await reload();
    if (c.mounted) await showReceipt(c, widget.aptId, p['id'] as int);
  }

  @override
  Widget build(BuildContext context) {
    return Loader(
      load: _load,
      builder: (c, d, reload) {
        final bills = (d['bills'] as List).cast<Map>();
        final fines = (d['fines'] as List).cast<Map>();
        final pays = (d['payments'] as List).cast<Map>();
        final selectable = <String>[
          for (final b in bills) if (_mine(b)) 'bill:${b['id']}',
          for (final f in fines) if (f['user_id'] == Session.uid) 'fine:${f['id']}',
        ];
        num total = 0;
        for (final b in bills) {
          if (sel.contains('bill:${b['id']}')) total += b['total'] as num;
        }
        for (final f in fines) {
          if (sel.contains('fine:${f['id']}')) total += f['amount'] as num;
        }
        final billsView = Column(children: [
          Expanded(
            child: refreshList(reload, [
              if (bills.isEmpty && fines.isEmpty) const Empty(Icons.check_circle_outline, 'Tidak ada tagihan', 'Semua tagihan Anda sudah lunas.'),
              if (selectable.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() {
                      if (sel.length == selectable.length) {
                        sel.clear();
                      } else {
                        sel
                          ..clear()
                          ..addAll(selectable);
                      }
                    }),
                    child: Text(sel.length == selectable.length ? 'Batal pilih semua' : 'Pilih semua'),
                  ),
                ),
              for (final f in fines)
                Panel(
                  color: kBad.withAlpha(12),
                  child: Row(children: [
                    if (f['user_id'] == Session.uid)
                      Checkbox(value: sel.contains('fine:${f['id']}'), onChanged: (v) => setState(() => v == true ? sel.add('fine:${f['id']}') : sel.remove('fine:${f['id']}'))),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Denda keterlambatan', style: TextStyle(fontWeight: FontWeight.w700, color: kBad)),
                      Text('${f['days']} hari terlambat${f['status'] == 'running' ? ' • masih bertambah' : ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
                    ])),
                    Text(rp(f['amount']), style: const TextStyle(fontWeight: FontWeight.w800, color: kBad)),
                  ]),
                ),
              for (final b in bills) _billCard(b),
            ]),
          ),
          if (sel.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kLine))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('${sel.length} item dipilih', style: const TextStyle(color: kMuted, fontSize: 12)),
                  Text(rp(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ])),
                FilledButton(onPressed: () => _pay(c, bills, fines, reload), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Bayar'))),
              ]),
            ),
        ]);
        final history = refreshList(reload, [
          if (pays.isEmpty) const Empty(Icons.receipt_long_outlined, 'Belum ada pembayaran'),
          for (final p in pays)
            Panel(
              onTap: () => showReceipt(context, widget.aptId, p['id'] as int),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['receipt_no'] ?? 'Pembayaran'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${fdt(p['paid_at'])} • ${p['method']}', style: const TextStyle(color: kMuted, fontSize: 12)),
                ])),
                Text(rp(p['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
        ]);
        return DefaultTabController(
          length: 2,
          child: Column(children: [
            const TabBar(tabs: [Tab(text: 'Tagihan'), Tab(text: 'Riwayat')]),
            Expanded(child: TabBarView(children: [billsView, history])),
          ]),
        );
      },
    );
  }

  Widget _billCard(Map b) {
    final mine = _mine(b);
    final overdue = b['is_overdue'] == true;
    final payable = b['payable'] == true;
    final items = (b['items'] as List).cast<Map>();
    return Panel(
      color: overdue ? kBad.withAlpha(10) : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (mine) Checkbox(value: sel.contains('bill:${b['id']}'), onChanged: (v) => setState(() => v == true ? sel.add('bill:${b['id']}') : sel.remove('bill:${b['id']}'))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${b['label']}', style: const TextStyle(fontWeight: FontWeight.w700))),
            overdue ? Pill('Terlambat ${b['days_late']} hari', kBad) : (payable ? Pill.status('unpaid') : Pill('Dibuka ${fd(b['payable_from'])}', kInfo)),
          ]),
          const SizedBox(height: 6),
          for (final it in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(children: [
                Expanded(child: Text('${it['label']}', style: const TextStyle(fontSize: 12, color: kMuted))),
                Text(rp(it['amount']), style: const TextStyle(fontSize: 12, color: kMuted)),
              ]),
            ),
          const Divider(height: 14),
          Row(children: [
            Expanded(child: Text('Jatuh tempo ${fd(b['due_date'])}', style: const TextStyle(fontSize: 12, color: kMuted))),
            Text(rp(b['total']), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          if (payable && !mine) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Dibayar oleh penghuni utama (${b['user']?['name'] ?? '-'}).', style: const TextStyle(fontSize: 12, color: kMuted))),
        ])),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Info
class TenantInfo extends StatelessWidget {
  final int aptId;
  final Map apt;
  final List<String> mods;
  const TenantInfo({super.key, required this.aptId, required this.apt, required this.mods});

  @override
  Widget build(BuildContext context) {
    final tabs = <(String, Widget)>[
      if (mods.contains('announcements')) ('Pengumuman', AnnouncementsList(aptId: aptId, canEdit: false)),
      if (mods.contains('facilities')) ('Fasilitas', FacilitiesList(aptId: aptId, canEdit: false)),
      ('Peraturan', _Rules(aptId: aptId, apt: apt)),
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

class _Rules extends StatelessWidget {
  final int aptId;
  final Map apt;
  const _Rules({required this.aptId, required this.apt});

  @override
  Widget build(BuildContext context) {
    return Loader(
      load: () => Api.get('/apartments/$aptId/dashboard'),
      builder: (c, d, reload) {
        final feats = ((d['occupancy']?['unit']?['type']?['features'] ?? []) as List).cast<dynamic>();
        final rules = '${apt['rules'] ?? ''}'.trim();
        return refreshList(reload, [
          if (apt['photo_url'] != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: NetImg('${apt['photo_url']}', w: double.infinity, h: 160, radius: 14)),
          const SectionTitle('Kontak & alamat'),
          Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InfoRow('Apartemen', '${apt['name']}'),
            InfoRow('Alamat', '${apt['address']}'),
            InfoRow('Kontak', '${apt['contact'] ?? '-'}'),
            InfoRow('Denda', '${rp(apt['late_fee_per_day'])} per hari per unit'),
          ])),
          if (feats.isNotEmpty) const SectionTitle('Fasilitas unit Anda'),
          if (feats.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: [for (final f in feats) Chip(label: Text('$f'))]),
          const SectionTitle('Peraturan apartemen'),
          Panel(child: Text(rules.isEmpty ? 'Belum ada peraturan yang dicatat pengelola.' : rules, style: const TextStyle(height: 1.5))),
        ]);
      },
    );
  }
}
