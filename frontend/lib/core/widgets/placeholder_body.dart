import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Body for screens not built yet.
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(context.l10n.comingSoon, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
