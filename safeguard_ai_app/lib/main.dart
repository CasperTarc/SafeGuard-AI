import 'package:flutter/material.dart';
import 'src/ui/startup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeGuardUIApp());
}

class SafeGuardUIApp extends StatelessWidget {
  const SafeGuardUIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeGuard AI — UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF0F0F3),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0096FB)),
      ),
      home: const OnboardingFlowPage(),
    );
  }
}