import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../documents/presentation/documents_page.dart';
import 'auth_controller.dart';
import 'auth_state.dart';
import 'login_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    switch (auth.status) {
      case AuthStatus.authenticated:
        return const DocumentsPage();
      case AuthStatus.checking:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.unauthenticated:
      case AuthStatus.authenticating:
      case AuthStatus.error:
        return const LoginPage();
    }
  }
}
