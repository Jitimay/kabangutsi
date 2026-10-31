import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../core/widgets/placeholder_body.dart';

class CallPage extends StatelessWidget {
  const CallPage({super.key});

  @override
  Widget build(BuildContext context) {
    final title = context.l10n.callTitle;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [LanguageMenu()]),
      body: PlaceholderBody(icon: Icons.call_outlined, title: title),
    );
  }
}
