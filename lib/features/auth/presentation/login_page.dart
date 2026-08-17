import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'auth_state.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.status == AuthStatus.authenticating;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child:
                    Icon(Icons.auto_awesome, size: 34, color: colors.onPrimary),
              ),
              const SizedBox(height: 24),
              const Text(
                'AI Support',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sign in to ask questions and receive grounded answers from trusted company knowledge.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, height: 1.5, color: Color(0xFF6E7383)),
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    auth.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => ref.read(authControllerProvider.notifier).login(),
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label:
                      Text(isLoading ? 'Signing in...' : 'Continue with Auth0'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
