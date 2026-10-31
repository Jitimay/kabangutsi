import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../core/widgets/placeholder_body.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navChat),
        actions: [
          IconButton(
            tooltip: l10n.modelPickerTitle,
            icon: const Icon(Icons.psychology_outlined),
            onPressed: () => context.go(CustomerRoutes.modelPicker),
          ),
          const LanguageMenu(),
        ],
      ),
      body: PlaceholderBody(icon: Icons.chat_bubble_outline, title: l10n.welcome),
    );
  }
}
