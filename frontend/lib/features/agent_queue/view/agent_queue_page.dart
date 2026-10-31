import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../core/widgets/placeholder_body.dart';

class AgentQueuePage extends StatelessWidget {
  const AgentQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final title = context.l10n.agentQueueTitle;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [LanguageMenu()]),
      body: PlaceholderBody(icon: Icons.support_agent, title: title),
    );
  }
}
