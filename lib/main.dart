import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'src/kds_screen.dart';
import 'src/models.dart';

/// XPOS Kitchen Display — a dedicated screen that mirrors restaurant kitchen
/// tickets from the XPOS register over the local network (no internet needed).
/// Pairs with xpos_lite_version's kitchen socket server (:7171, UDP :7172).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Kitchen screens must never sleep; ignore failures on unsupported hosts.
  WakelockPlus.enable().catchError((_) {});
  runApp(const KdsApp());
}

class KdsApp extends StatelessWidget {
  const KdsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'XPOS Kitchen Display',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: KColors.bg,
        colorScheme: base.colorScheme.copyWith(
          primary: KColors.primary,
          surface: KColors.surface,
        ),
      ),
      home: const KdsScreen(),
    );
  }
}
