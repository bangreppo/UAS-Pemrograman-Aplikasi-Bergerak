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

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: kPine, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 16),
        const Text('MyHously', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: kInk, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        const Text('Kelola sewa, tagihan, dan hunian dalam satu platform.', style: TextStyle(color: kMuted)),
      ]);
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

  Widget demo(String label, String mail) => ActionChip(label: Text(label), onPressed: () => setState(() {
        email.text = mail;
        pass.text = 'password';
      }));

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 28),
              const _Brand(),
              const SizedBox(height: 32),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                controller: pass,
                obscureText: hide,
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(labelText: 'Kata sandi', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide))),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Padding(padding: const EdgeInsets.symmetric(vertical: 13), child: Text(busy ? 'Memproses...' : 'Masuk')))),
              const SizedBox(height: 8),
              Center(child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())), child: const Text('Belum punya akun? Daftar'))),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Akun demo (kata sandi: password)', style: TextStyle(color: kMuted, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                demo('Owner', 'owner@myhously.test'),
                demo('Admin', 'admin1@myhously.test'),
                demo('Penghuni', 'penghuni1@myhously.test'),
                demo('Penghuni terlambat', 'penghuni4@myhously.test'),
                demo('Owner baru', 'ownerbaru@myhously.test'),
              ]),
            ]),
          ),
        ),
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

  Widget tf(TextEditingController c, String l, {TextInputType? t, bool obscure = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, keyboardType: t, obscureText: obscure, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder())),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBarOf('Buat akun'),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Satu akun untuk semua peran. Anda dapat menjadi pemilik, pengelola, atau penghuni di apartemen yang berbeda.', style: TextStyle(color: kMuted)),
              const SizedBox(height: 20),
              tf(name, 'Nama lengkap'),
              tf(email, 'Email', t: TextInputType.emailAddress),
              tf(phone, 'Nomor telepon', t: TextInputType.phone),
              tf(pass, 'Kata sandi (minimal 6 karakter)', obscure: true),
              const SizedBox(height: 4),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Padding(padding: const EdgeInsets.symmetric(vertical: 13), child: Text(busy ? 'Memproses...' : 'Daftar')))),
            ]),
          ),
        ),
      );
}
