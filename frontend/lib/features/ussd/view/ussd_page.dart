import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../core/widgets/placeholder_body.dart';

class UssdPage extends StatelessWidget {
  const UssdPage({super.key});

  @override
  Widget build(BuildContext context) {
    final title = context.l10n.ussdTitle;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [LanguageMenu()]),
      body: PlaceholderBody(icon: Icons.dialpad, title: title),
    );
  }
}
