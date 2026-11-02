import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection.dart';
import '../core/l10n/l10n.dart';
import '../core/locale/language_cubit.dart';
import '../core/theme/app_theme.dart';

/// Shared root widget for the customer and agent apps.
class KabangutsiApp extends StatelessWidget {
  const KabangutsiApp({super.key, required this.router, required this.title});

  final GoRouter router;
  final String Function(AppLocalizations l10n) title;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<LanguageCubit>(),
      child: BlocBuilder<LanguageCubit, Locale>(
        builder: (context, locale) => MaterialApp.router(
          onGenerateTitle: (context) => title(AppLocalizations.of(context)),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          locale: locale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: kLocalizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
  }
}
