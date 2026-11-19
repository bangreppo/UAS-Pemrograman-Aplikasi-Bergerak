import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';
import 'apartments.dart';

Future<void> _enter(BuildContext context, dynamic res) async {
  await Api.setToken(res['token'] as String);
  Session.user = Map<String, dynamic>.from(res['user'] as Map);
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ApartmentsPage()), (r) => false);
}

class _AuthHero extends StatelessWidget {
  final bool wide;
  const _AuthHero({required this.wide});

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.fromLTRB(wide ? 56 : 26, wide ? 0 : 54, 26, wide ? 0 : 70),
      child: Column(
        mainAxisAlignment: wide ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.apartment_rounded, color: kPine, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('MyHously', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          ]),
          SizedBox(height: wide ? 34 : 20),
          Text(wide ? 'Kelola apartemen\nlebih tenang,\nsemua dalam satu aplikasi.' : 'Kelola hunian,\nsemudah satu ketukan.', style: TextStyle(color: Colors.white, fontSize: wide ? 38 : 26, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          const SizedBox(height: 14),
          const Text('Tagihan sewa, pembayaran, laporan kerusakan, dan pengumuman untuk Owner, Admin, dan penghuni.', style: TextStyle(color: Colors.white70, height: 1.5)),
          if (wide) ...[
            const SizedBox(height: 26),
            for (final t in const ['Tagihan & denda otomatis', 'Bukti bayar PDF dan ekspor laporan', 'Data tiap apartemen terpisah dan aman'])
              Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [const Icon(Icons.check_circle, color: kBrass, size: 20), const SizedBox(width: 10), Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))])),
          ],
        ],
      ),
    );
    return Container(
      height: wide ? double.infinity : null,
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kPineDark, kPine, Color(0xFF1B8070)])),
      child: Stack(children: [
        Positioned(left: 0, right: 0, bottom: 0, height: wide ? 260 : 120, child: CustomPaint(painter: BuildingArt(Colors.white))),
        content,
      ]),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  bool hide = true;

  Future<void> submit() async {
    if (email.text.trim().isEmpty || pass.text.isEmpty) {
      toast(context, 'Email dan kata sandi wajib diisi.', error: true);
      return;
    }
    setState(() => busy = true);
    final res = await guard(context, () => Api.post('/login', {'email': email.text.trim(), 'password': pass.text}));
    if (!mounted) return;
    setState(() => busy = false);
    if (res != null) await _enter(context, res);
  }

  Widget demo(String label, IconData icon, String mail) => ActionChip(
        avatar: Icon(icon, size: 16, color: kPine),
        label: Text(label),
        backgroundColor: Colors.white,
        side: const BorderSide(color: kLine),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
        onPressed: () => setState(() {
          email.text = mail;
          pass.text = 'password';
        }),
      );

  Widget form() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Selamat datang', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.7)),
        const SizedBox(height: 4),
        const Text('Masuk untuk mengelola atau melihat hunian Anda.', style: TextStyle(color: kMuted)),
        const SizedBox(height: 24),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: deco('Email', prefix: const Icon(Icons.mail_outline))),
        const SizedBox(height: 14),
        TextField(
          controller: pass,
          obscureText: hide,
          onSubmitted: (_) => submit(),
          decoration: deco('Kata sandi', prefix: const Icon(Icons.lock_outline), suffix: IconButton(icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => hide = !hide))),
        ),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(busy ? 'Memproses...' : 'Masuk')))),
        const SizedBox(height: 6),
        Center(child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())), child: const Text('Belum punya akun? Daftar'))),
        const SizedBox(height: 14),
        Panel(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.bolt, size: 18, color: kBrass), SizedBox(width: 6), Text('Coba akun demo', style: TextStyle(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 2),
            const Text('Ketuk untuk mengisi otomatis (kata sandi: password).', style: TextStyle(color: kMuted, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              demo('Owner', Icons.workspace_premium_outlined, 'owner@myhously.test'),
              demo('Admin', Icons.admin_panel_settings_outlined, 'admin1@myhously.test'),
              demo('Penghuni', Icons.person_outline, 'penghuni1@myhously.test'),
              demo('Penghuni terlambat', Icons.warning_amber_rounded, 'penghuni4@myhously.test'),
              demo('Owner baru', Icons.add_business_outlined, 'ownerbaru@myhously.test'),
            ]),
          ]),
        ),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kPaper,
        body: LayoutBuilder(builder: (c, cons) {
          final wide = cons.maxWidth >= 820;
          if (wide) {
            return Row(children: [
              const Expanded(flex: 11, child: _AuthHero(wide: true)),
              Expanded(flex: 9, child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(40), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: form())))),
            ]);
          }
          return SingleChildScrollView(
            child: Column(children: [
              const _AuthHero(wide: false),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
                  decoration: const BoxDecoration(color: kPaper, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                  child: form(),
                ),
              ),
            ]),
          );
        }),
      );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;

  Future<void> submit() async {
    if ([name, email, phone, pass].any((c) => c.text.trim().isEmpty)) {
      toast(context, 'Semua kolom wajib diisi.', error: true);
      return;
    }
    setState(() => busy = true);
    final res = await guard(context, () => Api.post('/register', {'name': name.text.trim(), 'email': email.text.trim(), 'phone': phone.text.trim(), 'password': pass.text}));
    if (!mounted) return;
    setState(() => busy = false);
    if (res != null) await _enter(context, res);
  }

  Widget tf(TextEditingController c, String l, IconData icon, {TextInputType? t, bool obscure = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(controller: c, keyboardType: t, obscureText: obscure, decoration: deco(l, prefix: Icon(icon))),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBarOf(''),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Buat akun', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.7)),
                const SizedBox(height: 6),
                const Text('Satu akun untuk semua peran. Anda dapat menjadi pemilik, pengelola, atau penghuni di apartemen yang berbeda.', style: TextStyle(color: kMuted, height: 1.5)),
                const SizedBox(height: 24),
                tf(name, 'Nama lengkap', Icons.badge_outlined),
                tf(email, 'Email', Icons.mail_outline, t: TextInputType.emailAddress),
                tf(phone, 'Nomor telepon', Icons.phone_outlined, t: TextInputType.phone),
                tf(pass, 'Kata sandi (minimal 6 karakter)', Icons.lock_outline, obscure: true),
                const SizedBox(height: 6),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(busy ? 'Memproses...' : 'Daftar')))),
              ]),
            ),
          ),
        ),
      );
}
