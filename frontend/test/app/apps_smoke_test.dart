import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/app/kabangutsi_app.dart';
import 'package:kabangutsi/core/di/injection.dart';
import 'package:kabangutsi/core/env/env.dart';
import 'package:kabangutsi/core/router/agent_router.dart';
import 'package:kabangutsi/core/router/customer_router.dart';

void main() {
  setUp(() => configureDependencies(
        env: const Env(apiUrl: 'http://test', useMock: true),
      ));

  testWidgets('customer app opens on chat and switches language to Kirundi',
      (tester) async {
    await tester.pumpWidget(KabangutsiApp(
      router: buildCustomerRouter(),
      title: (l) => l.appTitleCustomer,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Discussion'), findsWidgets);

    await tester.tap(find.byKey(const Key('language_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ikirundi').last);
    await tester.pumpAndSettle();
    expect(find.text('Ikiganiro'), findsWidgets);
  });

  testWidgets('customer app navigates to every tab and service', (tester) async {
    await tester.pumpWidget(KabangutsiApp(
      router: buildCustomerRouter(),
      title: (l) => l.appTitleCustomer,
    ));
    await tester.pumpAndSettle();
    for (final tab in ['Appel', 'USSD', 'Services']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    expect(find.text('Bloquer une carte'), findsOneWidget);
    await tester.tap(find.text('Bloquer une carte'));
    await tester.pumpAndSettle();
    expect(find.text('Bientôt disponible'), findsOneWidget);
  });

  testWidgets('agent app opens on the queue', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(KabangutsiApp(
      router: buildAgentRouter(),
      title: (l) => l.appTitleAgent,
    ));
    await tester.pumpAndSettle();
    expect(find.text("File d'appels"), findsWidgets);
  });

  test('env derives REST and WebSocket URLs', () {
    const env = Env(apiUrl: 'http://localhost:8000', useMock: false);
    expect(env.restBaseUrl, 'http://localhost:8000/v1');
    expect(env.wsBaseUrl, 'ws://localhost:8000/v1/ws');
  });
}
