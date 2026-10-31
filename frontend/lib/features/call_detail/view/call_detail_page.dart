import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../core/widgets/placeholder_body.dart';

class CallDetailPage extends StatelessWidget {
  const CallDetailPage({super.key, required this.callId});

  final String callId;

  @override
  Widget build(BuildContext context) {
    final title = context.l10n.callDetailTitle;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [LanguageMenu()]),
      body: PlaceholderBody(icon: Icons.receipt_long_outlined, title: title),
    );
  }
}
