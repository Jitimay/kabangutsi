import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../core/widgets/placeholder_body.dart';

class CardBlockPage extends StatelessWidget {
  const CardBlockPage({super.key});

  @override
  Widget build(BuildContext context) {
    final title = context.l10n.cardBlockTitle;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [LanguageMenu()]),
      body: PlaceholderBody(icon: Icons.credit_card_off_outlined, title: title),
    );
  }
}
