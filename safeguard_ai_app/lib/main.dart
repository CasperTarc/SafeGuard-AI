// Main entry — register routes that map to actual classes (CancelPageView is defined in cancel.dart).
// Sent and confirmation are presented as overlays (showSentDialog/showConfirmationDialog), so they
// are not registered as named routes here.

import 'package:flutter/material.dart';
import 'src/ui/home_scaffold.dart';
import 'src/ui/cancel.dart'; // provides CancelPageView + showCancelDialog
import 'src/ui/confirmation.dart'; // provides showConfirmationDialog()

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
      routes: {
        '/cancel': (_) => const CancelPageView(),
        // '/sent' is intentionally not registered because Sent is shown via showSentDialog(...)
      },
      home: const HomeScaffold(),
    );
  }
}