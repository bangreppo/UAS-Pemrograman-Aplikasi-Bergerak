import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';

const kInk = Color(0xFF17211F);
const kPine = Color(0xFF1F5F5B);
const kBrass = Color(0xFFC8963E);
const kPaper = Color(0xFFF6F7F5);
const kLine = Color(0xFFE1E6E3);
const kMuted = Color(0xFF66726E);
const kOk = Color(0xFF2E7D4F);
const kWarn = Color(0xFFB7791F);
const kBad = Color(0xFFB3382C);
const kInfo = Color(0xFF2F6690);

class Session {
  static Map<String, dynamic> user = {};
  static int get uid => (user['id'] ?? 0) as int;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kPine, brightness: Brightness.light).copyWith(primary: kPine, secondary: kBrass, surface: Colors.white);
  return ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: kPaper);
}

AppBar appBarOf(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) => AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: kPaper,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: actions,
      bottom: bottom,
    );

final NumberFormat _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
String rp(dynamic n) => _rp.format(n is num ? n : (num.tryParse('${n ?? 0}') ?? 0));

DateTime? pd(dynamic s) => s == null ? null : DateTime.tryParse('$s');
String fd(dynamic s) {
  final d = pd(s);
  return d == null ? '-' : DateFormat('d MMM yyyy', 'id_ID').format(d.toLocal());
}

String fdt(dynamic s) {
  final d = pd(s);
  return d == null ? '-' : DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(d.toLocal());
}

String bulanTahun(dynamic s) {
  final d = pd(s);
  return d == null ? '-' : DateFormat('MMMM yyyy', 'id_ID').format(d);
}

(String, Color) statusInfo(String s) {
  switch (s) {
    case 'paid':
      return ('Lunas', kOk);
    case 'unpaid':
      return ('Belum bayar', kWarn);
    case 'overdue':
      return ('Terlambat', kBad);
    case 'running':
      return ('Berjalan', kBad);
    case 'due':
      return ('Belum dibayar', kWarn);
    case 'waived':
      return ('Dibebaskan', kMuted);
    case 'available':
      return ('Tersedia', kOk);
    case 'occupied':
      return ('Terisi', kPine);
    case 'maintenance':
      return ('Tidak tersedia', kMuted);
    case 'closed':
      return ('Ditutup sementara', kWarn);
    case 'pending':
      return ('Menunggu', kWarn);
    case 'approved':
      return ('Diterima', kOk);
    case 'rejected':
      return ('Ditolak', kBad);
    case 'cancelled':
      return ('Dibatalkan', kMuted);
    case 'menunggu':
      return ('Menunggu respons', kWarn);
    case 'diterima':
      return ('Diterima', kInfo);
    case 'ditolak':
      return ('Ditolak', kBad);
    case 'ditangani':
      return ('Sedang ditangani', kBrass);
    case 'selesai':
      return ('Selesai', kOk);
    default:
      return (s, kMuted);
  }
}

String facilityStatusLabel(String s) => s == 'maintenance' ? 'Dalam perbaikan' : statusInfo(s).$1;

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  factory Pill.status(String s) {
    final i = statusInfo(s);
    return Pill(i.$1, i.$2);
  }
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class Panel extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  const Panel({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14), this.color});
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color ?? Colors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: kLine)),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kInk))),
          if (trailing != null) trailing!,
        ]),
      );
}

class InfoRow extends StatelessWidget {
  final String label, value;
  const InfoRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 118, child: Text(label, style: const TextStyle(color: kMuted, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      );
}

class Empty extends StatelessWidget {
  final IconData icon;
  final String title, hint;
  const Empty(this.icon, this.title, [this.hint = '', Key? key]) : super(key: key);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(children: [
          Icon(icon, size: 44, color: kMuted),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(hint, textAlign: TextAlign.center, style: const TextStyle(color: kMuted)),
          ],
        ]),
      );
}

void toast(BuildContext c, String m, {bool error = false}) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), backgroundColor: error ? kBad : kInk, behavior: SnackBarBehavior.floating));
}

/// Menjalankan aksi API; menampilkan pesan galat bila gagal. Mengembalikan null jika gagal.
Future<T?> guard<T>(BuildContext c, Future<T> Function() f, {String? ok}) async {
  try {
    final r = await f();
    if (ok != null && c.mounted) toast(c, ok);
    return r;
  } on ApiError catch (e) {
    if (c.mounted) toast(c, e.message, error: true);
  } catch (e) {
    if (c.mounted) toast(c, 'Terjadi kesalahan: $e', error: true);
  }
  return null;
}

Future<bool> confirmDlg(BuildContext c, String title, String msg, {String ok = 'Ya'}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

Future<void> infoDlg(BuildContext c, String title, Widget content) => showDialog<void>(
      context: c,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: content),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup'))],
      ),
    );

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView(this.error, this.onRetry, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 44, color: kMuted),
            const SizedBox(height: 12),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
            if (Navigator.of(context).canPop()) TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Kembali')),
          ]),
        ),
      );
}

class Loader extends StatefulWidget {
  final Future<dynamic> Function() load;
  final Widget Function(BuildContext, dynamic, Future<void> Function()) builder;
  const Loader({super.key, required this.load, required this.builder});
  @override
  State<Loader> createState() => _LoaderState();
}

class _LoaderState extends State<Loader> {
  dynamic data;
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        data = d;
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) return const Center(child: CircularProgressIndicator());
    if (data == null && error != null) {
      return ErrorView(error!, () {
        setState(() => loading = true);
        reload();
      });
    }
    return widget.builder(context, data, reload);
  }
}

Widget refreshList(Future<void> Function() reload, List<Widget> children, {EdgeInsets padding = const EdgeInsets.fromLTRB(16, 4, 16, 90)}) => RefreshIndicator(
      onRefresh: reload,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: padding, children: children),
    );

class ChipsBar extends StatelessWidget {
  final List<List<String>> options;
  final String value;
  final ValueChanged<String> onChanged;
  const ChipsBar(this.options, this.value, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: options
              .map((o) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(o[1]), selected: value == o[0], onSelected: (_) => onChanged(o[0])),
                  ))
              .toList(),
        ),
      );
}

// ---------------------------------------------------------------- Formulir
class Field {
  final String key, label, type;
  final bool required;
  final List<List<String>>? options;
  final String? hint;
  const Field(this.key, this.label, {this.type = 'text', this.required = false, this.options, this.hint});
}

Future<Map<String, dynamic>?> showForm(BuildContext c,
    {required String title, required List<Field> fields, Map<String, dynamic>? initial, String submit = 'Simpan'}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: c,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _FormSheet(title: title, submit: submit, fields: fields, initial: initial ?? {}),
  );
}

class _FormSheet extends StatefulWidget {
  final String title, submit;
  final List<Field> fields;
  final Map<String, dynamic> initial;
  const _FormSheet({required this.title, required this.submit, required this.fields, required this.initial});
  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final _key = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {};
  final Map<String, dynamic> _v = {};
  final Map<String, String?> _err = {};

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final init = widget.initial[f.key];
      if (f.type == 'select') {
        _v[f.key] = init?.toString();
      } else if (f.type == 'switch') {
        _v[f.key] = init == true || init == 1;
      } else if (f.type == 'date') {
        final s = init == null ? null : '$init';
        _v[f.key] = s == null ? null : (s.length >= 10 ? s.substring(0, 10) : s);
      } else {
        var text = '';
        if (init is List) {
          text = init.join(', ');
        } else if (init != null) {
          text = '$init';
        }
        _c[f.key] = TextEditingController(text: text);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final ok = _key.currentState!.validate();
    var extraOk = true;
    setState(() {
      _err.clear();
      for (final f in widget.fields) {
        if ((f.type == 'select' || f.type == 'date') && f.required && (_v[f.key] == null || '${_v[f.key]}'.isEmpty)) {
          _err[f.key] = 'Wajib diisi';
          extraOk = false;
        }
      }
    });
    if (!ok || !extraOk) return;
    final out = <String, dynamic>{};
    for (final f in widget.fields) {
      if (f.type == 'switch') {
        out[f.key] = _v[f.key] == true;
      } else if (f.type == 'select' || f.type == 'date') {
        if (_v[f.key] != null && '${_v[f.key]}'.isNotEmpty) out[f.key] = _v[f.key];
      } else {
        final t = _c[f.key]!.text.trim();
        if (t.isEmpty) continue;
        if (f.type == 'number') {
          out[f.key] = num.tryParse(t.replaceAll(',', '.'));
        } else if (f.type == 'csv') {
          out[f.key] = t.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        } else {
          out[f.key] = t;
        }
      }
    }
    Navigator.pop(context, out);
  }

  Widget _field(Field f) {
    final label = f.required ? '${f.label} *' : f.label;
    switch (f.type) {
      case 'switch':
        return SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(f.label), value: _v[f.key] == true, onChanged: (x) => setState(() => _v[f.key] = x));
      case 'date':
        return InkWell(
          onTap: () async {
            final cur = DateTime.tryParse('${_v[f.key] ?? ''}') ?? DateTime.now();
            final d = await showDatePicker(context: context, initialDate: cur, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setState(() => _v[f.key] = DateFormat('yyyy-MM-dd').format(d));
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), errorText: _err[f.key], suffixIcon: const Icon(Icons.calendar_today, size: 18)),
            child: Text(_v[f.key] == null ? 'Pilih tanggal' : fd(_v[f.key])),
          ),
        );
      case 'select':
        final opts = f.options ?? [];
        final cur = opts.any((o) => o[0] == _v[f.key]) ? _v[f.key] as String? : null;
        return DropdownButtonFormField<String>(
          value: cur,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), errorText: _err[f.key]),
          items: opts.map((o) => DropdownMenuItem<String>(value: o[0], child: Text(o[1], overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _v[f.key] = v),
        );
      default:
        return TextFormField(
          controller: _c[f.key],
          obscureText: f.type == 'password',
          maxLines: f.type == 'multiline' ? 3 : 1,
          keyboardType: f.type == 'number' ? const TextInputType.numberWithOptions(decimal: true) : (f.type == 'multiline' ? TextInputType.multiline : TextInputType.text),
          decoration: InputDecoration(labelText: label, hintText: f.hint, border: const OutlineInputBorder()),
          validator: (v) {
            final t = (v ?? '').trim();
            if (f.required && t.isEmpty) return 'Wajib diisi';
            if (f.type == 'number' && t.isNotEmpty && num.tryParse(t.replaceAll(',', '.')) == null) return 'Masukkan angka';
            return null;
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Form(
            key: _key,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              for (final f in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(f)),
              const SizedBox(height: 4),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(widget.submit)))),
            ]),
          ),
        ),
      );
}

/// Menu aksi dalam bottom sheet. Mengembalikan indeks pilihan.
Future<int?> actionSheet(BuildContext c, String title, List<(IconData, String)> actions) {
  return showModalBottomSheet<int>(
    context: c,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 6), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        for (var i = 0; i < actions.length; i++)
          ListTile(leading: Icon(actions[i].$1), title: Text(actions[i].$2), onTap: () => Navigator.pop(c, i)),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

// ---------------------------------------------------------------- Foto & tautan
Future<void> openUrl(BuildContext c, String url) async {
  bool ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && c.mounted) toast(c, 'Tidak dapat membuka tautan.', error: true);
}

class PickedPhoto {
  final Uint8List bytes;
  final String name;
  PickedPhoto(this.bytes, this.name);
}

Future<PickedPhoto?> pickPhoto() async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
  if (f == null) return null;
  return PickedPhoto(await f.readAsBytes(), f.name.isEmpty ? 'foto.jpg' : f.name);
}

Future<List<PickedPhoto>> pickPhotos({int max = 3}) async {
  if (max <= 0) return [];
  final files = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 1600);
  final out = <PickedPhoto>[];
  for (final f in files.take(max)) {
    out.add(PickedPhoto(await f.readAsBytes(), f.name.isEmpty ? 'foto.jpg' : f.name));
  }
  return out;
}

class NetImg extends StatelessWidget {
  final String url;
  final double? w, h;
  final double radius;
  const NetImg(this.url, {super.key, this.w, this.h, this.radius = 10});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          url,
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(width: w, height: h, color: kLine, child: const Icon(Icons.broken_image_outlined, color: kMuted)),
          loadingBuilder: (c, child, p) => p == null ? child : Container(width: w, height: h, color: kLine),
        ),
      );
}

class Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;
  const Avatar(this.url, this.name, {super.key, this.radius = 22});
  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: kPine,
      foregroundColor: Colors.white,
      child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: radius * 0.8)),
    );
    if (url == null) return fallback;
    return ClipOval(child: SizedBox(width: radius * 2, height: radius * 2, child: Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)));
  }
}
