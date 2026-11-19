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
      builder: (context, child) => LayoutBuilder(
        builder: (c, cons) {
          final w = cons.maxWidth > 1080 ? 1080.0 : cons.maxWidth;
          return ColoredBox(
            color: const Color(0xFFE8E4DA),
            child: Center(
              child: SizedBox(
                width: w,
                height: cons.maxHeight,
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: kPaper, boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 30)]),
                  child: ClipRect(child: child),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
