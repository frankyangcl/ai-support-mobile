import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../features/auth/presentation/auth_gate.dart';

class AISupportApp extends ConsumerWidget {
  const AISupportApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configurationError = ref.watch(appConfigProvider).configurationError;
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
      home: configurationError == null
          ? const AuthGate()
          : _ConfigurationError(message: configurationError),
    );
  }
}

class _ConfigurationError extends StatelessWidget {
  const _ConfigurationError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_suggest_outlined, size: 44),
                  const SizedBox(height: 16),
                  const Text('Configuration required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
}
