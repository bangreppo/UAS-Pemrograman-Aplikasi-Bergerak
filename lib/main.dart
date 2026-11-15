import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'api.dart';
import 'ui.dart';
import 'screens/auth.dart';
import 'screens/apartments.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await Api.init();
  Api.onUnauthorized = () {
    Api.token = null;
    navKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
  };
  runApp(const MyHouslyApp());
}

class MyHouslyApp extends StatelessWidget {
  const MyHouslyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyHously',
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Api.token == null ? const LoginPage() : const ApartmentsPage(),
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFE6EAE8),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: ClipRect(child: child))),
      ),
    );
  }
}
