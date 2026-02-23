import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_info.dart';
import 'providers/rules_provider.dart';
import 'providers/conversion_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RulesProvider()..loadRules()),
        ChangeNotifierProvider(create: (_) => ConversionProvider()),
      ],
      child: const ApdDcm2niixApp(),
    ),
  );
}

class ApdDcm2niixApp extends StatelessWidget {
  const ApdDcm2niixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2F5D8A),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2F5D8A),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
