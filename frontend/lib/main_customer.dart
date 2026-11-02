import 'package:flutter/material.dart';

import 'app/kabangutsi_app.dart';
import 'core/di/injection.dart';
import 'core/router/customer_router.dart';

/// Customer app (Android + web).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(KabangutsiApp(
    router: buildCustomerRouter(),
    title: (l10n) => l10n.appTitleCustomer,
  ));
}
