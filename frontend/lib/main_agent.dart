import 'package:flutter/material.dart';

import 'app/kabangutsi_app.dart';
import 'core/di/injection.dart';
import 'core/router/agent_router.dart';

/// Agent dashboard (web).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(KabangutsiApp(
    router: buildAgentRouter(),
    title: (l10n) => l10n.appTitleAgent,
  ));
}
