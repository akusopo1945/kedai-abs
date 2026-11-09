import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/pos_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final posProvider = PosProvider();
  unawaited(posProvider.init());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: posProvider),
      ],
      child: const KedaiPosApp(),
    ),
  );
}

class KedaiPosApp extends StatelessWidget {
  const KedaiPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kedai POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Selector<PosProvider, bool>(
        selector: (_, pos) => pos.isInitialized,
        builder: (_, isInitialized, __) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: isInitialized
                ? const MainNavigationScreen()
                : const SplashScreen(),
          );
        },
      ),
    );
  }
}
