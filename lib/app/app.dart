import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_gate.dart';

class AISupportApp extends StatelessWidget {
  const AISupportApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF4756B3);
    return MaterialApp(
      title: 'AI Support',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8FC),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const AuthGate(),
    );
  }
}
