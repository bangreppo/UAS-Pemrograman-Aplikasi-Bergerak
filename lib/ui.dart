import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';

// ================================================================ Palet
const kInk = Color(0xFF13201E);
const kPine = Color(0xFF0F5C58);
const kPineDark = Color(0xFF083F3C);
const kMint = Color(0xFFE3F1EE);
const kBrass = Color(0xFFE5A23A);
const kPaper = Color(0xFFF6F4EF);
const kLine = Color(0xFFE7E3DA);
const kMuted = Color(0xFF69756F);
const kOk = Color(0xFF1E8A5A);
const kWarn = Color(0xFFC7861A);
const kBad = Color(0xFFC13F2C);
const kInfo = Color(0xFF2B6CB0);
const kShadow = Color(0x14102A27);

class Session {
  static Map<String, dynamic> user = {};
  static int get uid => (user['id'] ?? 0) as int;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kPine, brightness: Brightness.light)
      .copyWith(primary: kPine, onPrimary: Colors.white, secondary: kBrass, surface: Colors.white);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: kPaper);
  final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: kInk, displayColor: kInk);
  final shape14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return base.copyWith(
    textTheme: text,
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: kMint,
      height: 68,
      elevation: 8,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: shape14, minimumSize: const Size(0, 48), textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: shape14, minimumSize: const Size(0, 46), side: const BorderSide(color: kLine), foregroundColor: kPine, textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kPine, textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: shape14),
  );
}

PreferredSizeWidget appBarOf(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) => AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.2)),
      backgroundColor: kPaper,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      actions: actions,
      bottom: bottom,
    );

// ================================================================ Format
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

// ================================================================ Dekorasi input
final OutlineInputBorder kInputBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kLine));
final OutlineInputBorder kInputFocus = OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kPine, width: 1.6));
final OutlineInputBorder kInputError = OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBad));

InputDecoration deco(String label, {String? hint, String? error, Widget? suffix, Widget? prefix}) => InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      suffixIcon: suffix,
      prefixIcon: prefix,
      filled: true,
      fillColor: Colors.white,
      border: kInputBorder,
      enabledBorder: kInputBorder,
      focusedBorder: kInputFocus,
      errorBorder: kInputError,
      focusedErrorBorder: kInputError,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );

// ================================================================ Animasi & komponen dasar
class FadeIn extends StatelessWidget {
  final Widget child;
  const FadeIn({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        builder: (c, v, ch) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 10), child: ch)),
        child: child,
      );
}

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge(this.icon, {super.key, this.color = kPine, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(size * 0.32)),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}

class Panel extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;
  const Panel({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.margin = const EdgeInsets.only(bottom: 12), this.color});
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return FadeIn(
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: radius,
          border: Border.all(color: kLine),
          boxShadow: const [BoxShadow(color: kShadow, blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(borderRadius: radius, onTap: onTap, child: Padding(padding: padding, child: SizedBox(width: double.infinity, child: child))),
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final int alpha;
  const _Circle(this.size, this.alpha);
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(alpha)));
}

class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext context) => FadeIn(
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x33083F3C), blurRadius: 24, offset: Offset(0, 12))]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kPineDark, kPine, Color(0xFF1B8070)])),
              child: Stack(children: [
                const Positioned(right: -46, top: -46, child: _Circle(170, 22)),
                const Positioned(left: -36, bottom: -56, child: _Circle(150, 16)),
                Padding(padding: padding, child: SizedBox(width: double.infinity, child: child)),
              ]),
            ),
          ),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
        child: Row(children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: kBrass, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: kInk, letterSpacing: -0.1))),
          if (trailing != null) trailing!,
        ]),
      );
}

class InfoRow extends StatelessWidget {
  final String label, value;
  const InfoRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 118, child: Text(label, style: const TextStyle(color: kMuted, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        ]),
      );
}

class Empty extends StatelessWidget {
  final IconData icon;
  final String title, hint;
  const Empty(this.icon, this.title, [this.hint = '', Key? key]) : super(key: key);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 28),
        child: Column(children: [
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(color: kMint, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: kPine),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(hint, textAlign: TextAlign.center, style: const TextStyle(color: kMuted, height: 1.45)),
          ],
        ]),
      );
}

class StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const StatTile(this.label, this.value, this.icon, {super.key, this.color = kPine, this.onTap});
  @override
  Widget build(BuildContext context) => Panel(
        onTap: onTap,
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          IconBadge(icon, color: color, size: 42),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color == kPine ? kInk : color)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 12)),
          ])),
        ]),
      );
}

/// Menata anak-anak dalam grid adaptif (2 kolom di HP, 4 di layar lebar).
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int wideCols;
  const AdaptiveGrid(this.children, {super.key, this.wideCols = 4});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, cons) {
        final cols = cons.maxWidth > 640 ? wideCols : 2;
        final w = (cons.maxWidth - 12 * (cols - 1)) / cols;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(spacing: 12, runSpacing: 12, children: [for (final ch in children) SizedBox(width: w, child: ch)]),
        );
      });
}

class DonutRing extends StatelessWidget {
  final double value;
  final double size, stroke;
  final Color color;
  final Widget? child;
  const DonutRing({super.key, required this.value, this.size = 96, this.stroke = 11, this.color = kPine, this.child});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _RingPainter(value.clamp(0.0, 1.0).toDouble(), stroke, color), child: Center(child: child)),
      );
}

class _RingPainter extends CustomPainter {
  final double value, stroke;
  final Color color;
  _RingPainter(this.value, this.stroke, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = kMint;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (value > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value || old.color != color;
}

/// Ilustrasi siluet gedung apartemen (dekoratif).
class BuildingArt extends CustomPainter {
  final Color color;
  BuildingArt(this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    const blds = [
      [0.03, 0.52, 0.19],
      [0.24, 0.82, 0.21],
      [0.48, 0.64, 0.18],
      [0.69, 0.96, 0.22],
      [0.89, 0.46, 0.13],
    ];
    final body = Paint()..color = color.withAlpha(44);
    final win = Paint()..color = color.withAlpha(95);
    for (final b in blds) {
      final bw = w * b[2], bh = h * b[1], x = w * b[0], y = h - bh;
      canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x, y, bw, bh), topLeft: const Radius.circular(10), topRight: const Radius.circular(10)), body);
      final cols = (bw / 18).floor().clamp(2, 6).toInt();
      final rows = ((bh - 16) / 24).floor();
      final cw = (bw - 16) / cols;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if ((r * 3 + c * 5 + (b[0] * 100).toInt()) % 4 == 0) continue;
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 8 + c * cw + 2, y + 14 + r * 24, cw - 6, 11), const Radius.circular(3)), win);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BuildingArt old) => old.color != color;
}

// ================================================================ Dialog & notifikasi
void toast(BuildContext c, String m, {bool error = false}) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(m, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: error ? kBad : kInk,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
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
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(msg, style: const TextStyle(height: 1.45)),
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(child: content),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup'))],
      ),
    );

// ================================================================ Memuat data
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView(this.error, this.onRetry, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 84, height: 84, decoration: BoxDecoration(color: kBad.withAlpha(24), shape: BoxShape.circle), child: const Icon(Icons.cloud_off_rounded, size: 38, color: kBad)),
            const SizedBox(height: 16),
            Text('$error', textAlign: TextAlign.center, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
            if (Navigator.of(context).canPop()) TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Kembali')),
          ]),
        ),
      );
}

class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key});
  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double w, double h) => Container(width: w, height: h, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(8)));

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
        child: ListView(physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
          Container(height: 150, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(26))),
          const SizedBox(height: 16),
          for (var i = 0; i < 4; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
              child: Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(14))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_bar(160, 13), const SizedBox(height: 8), _bar(100, 10)])),
              ]),
            ),
        ]),
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
    if (loading && data == null) return const SkeletonList();
    if (data == null && error != null) {
      return ErrorView(error!, () {
        setState(() => loading = true);
        reload();
      });
    }
    return widget.builder(context, data, reload);
  }
}

Widget refreshList(Future<void> Function() reload, List<Widget> children, {EdgeInsets padding = const EdgeInsets.fromLTRB(16, 6, 16, 96)}) => RefreshIndicator(
      color: kPine,
      onRefresh: reload,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: padding, children: children),
    );

class ChipsBar extends StatelessWidget {
  final List<List<String>> options;
  final String value;
  final ValueChanged<String> onChanged;
  final EdgeInsets padding;
  const ChipsBar(this.options, this.value, this.onChanged, {super.key, this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 10)});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: options.map((o) {
            final sel = value == o[0];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(o[1]),
                selected: sel,
                showCheckmark: false,
                selectedColor: kPine,
                backgroundColor: Colors.white,
                side: BorderSide(color: sel ? kPine : kLine),
                shape: const StadiumBorder(),
                labelStyle: TextStyle(color: sel ? Colors.white : kInk, fontWeight: FontWeight.w700, fontSize: 13),
                onSelected: (_) => onChanged(o[0]),
              ),
            );
          }).toList(),
        ),
      );
}

// ================================================================ Formulir
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
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 620),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
        return Container(
          decoration: BoxDecoration(color: kPaper, borderRadius: BorderRadius.circular(14)),
          child: SwitchListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14), title: Text(f.label, style: const TextStyle(fontWeight: FontWeight.w600)), value: _v[f.key] == true, onChanged: (x) => setState(() => _v[f.key] = x)),
        );
      case 'date':
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final cur = DateTime.tryParse('${_v[f.key] ?? ''}') ?? DateTime.now();
            final d = await showDatePicker(context: context, initialDate: cur, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setState(() => _v[f.key] = DateFormat('yyyy-MM-dd').format(d));
          },
          child: InputDecorator(
            decoration: deco(label, error: _err[f.key], suffix: const Icon(Icons.calendar_today_outlined, size: 18)),
            child: Text(_v[f.key] == null ? 'Pilih tanggal' : fd(_v[f.key]), style: TextStyle(color: _v[f.key] == null ? kMuted : kInk)),
          ),
        );
      case 'select':
        final opts = f.options ?? [];
        final cur = opts.any((o) => o[0] == _v[f.key]) ? _v[f.key] as String? : null;
        return DropdownButtonFormField<String>(
          value: cur,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          decoration: deco(label, error: _err[f.key]),
          items: opts.map((o) => DropdownMenuItem<String>(value: o[0], child: Text(o[1], overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _v[f.key] = v),
        );
      default:
        return TextFormField(
          controller: _c[f.key],
          obscureText: f.type == 'password',
          maxLines: f.type == 'multiline' ? 3 : 1,
          keyboardType: f.type == 'number' ? const TextInputType.numberWithOptions(decimal: true) : (f.type == 'multiline' ? TextInputType.multiline : TextInputType.text),
          decoration: deco(label, hint: f.hint),
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
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          child: Form(
            key: _key,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              const SizedBox(height: 16),
              for (final f in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 14), child: _field(f)),
              const SizedBox(height: 2),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(widget.submit)))),
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
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 620),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 8), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        for (var i = 0; i < actions.length; i++)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 22),
            leading: IconBadge(actions[i].$1, size: 40),
            title: Text(actions[i].$2, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: kMuted),
            onTap: () => Navigator.pop(c, i),
          ),
        const SizedBox(height: 10),
      ]),
    ),
  );
}

// ================================================================ Foto & tautan
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
  const NetImg(this.url, {super.key, this.w, this.h, this.radius = 12});
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
    final fallback = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kPine, Color(0xFF1B8070)])),
      alignment: Alignment.center,
      child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: radius * 0.85)),
    );
    if (url == null) return fallback;
    return ClipOval(child: SizedBox(width: radius * 2, height: radius * 2, child: Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)));
  }
}
