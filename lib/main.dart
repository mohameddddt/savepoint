import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dev_seed.dart';
import 'screens/settings.dart';
import 'screens/shell.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  PaintingBinding.instance.imageCache.maximumSizeBytes = 160 << 20;
  store = Store();
  await store.load();
  if (kSeed) {
    seedDemo();
    store.setKv('onboarded', '1');
  }
  AppLifecycleListener(onStateChange: (s) {
    if (s != AppLifecycleState.resumed) store.db.flush();
  });
  runApp(App(home: store.onboarded ? const Shell() : const WelcomeScreen()));
}

class App extends StatelessWidget {
  const App({super.key, required this.home});
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Accent>(
      valueListenable: store.accentVN,
      builder: (_, a, _) => MaterialApp(
        title: 'Savepoint',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(a),
        themeAnimationDuration: const Duration(milliseconds: 350),
        home: home,
      ),
    );
  }
}
