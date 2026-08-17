import 'package:flutter/material.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({required this.onRetry, super.key});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Text(
            'Unable to load documents.',
            style: TextStyle(color: Color(0xFF6E7383)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
