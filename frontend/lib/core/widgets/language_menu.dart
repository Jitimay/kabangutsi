import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/l10n.dart';
import '../locale/language_cubit.dart';

/// App bar action to switch the UI language between fr, en and rn.
class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = context.watch<LanguageCubit>().state;
    String label(Locale l) => switch (l.languageCode) {
          'fr' => l10n.languageFr,
          'en' => l10n.languageEn,
          _ => l10n.languageRn,
        };
    return PopupMenuButton<Locale>(
      key: const Key('language_menu'),
      tooltip: l10n.language,
      icon: const Icon(Icons.translate),
      initialValue: current,
      onSelected: context.read<LanguageCubit>().select,
      itemBuilder: (_) => [
        for (final l in kSupportedLocales)
          PopupMenuItem(value: l, child: Text(label(l))),
      ],
    );
  }
}
