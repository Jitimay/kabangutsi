import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/app/kabangutsi_app.dart';
import 'package:kabangutsi/core/di/injection.dart';
import 'package:kabangutsi/core/env/env.dart';
import 'package:kabangutsi/core/locale/language_cubit.dart';
import 'package:kabangutsi/core/router/customer_router.dart';
import 'package:kabangutsi/data/mock/mock_backend.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';
import 'package:kabangutsi/features/chat/bloc/chat_bloc.dart';
import 'package:kabangutsi/features/document_scan/services/document_picker.dart';

import 'doc_fixtures.dart';

/// Returns the next file it is given; camera on or off.
class FakePicker implements DocumentPicker {
  FakePicker({this.canUseCamera = false});

  @override
  final bool canUseCamera;
  FileUpload? next;
  int photos = 0;

  @override
  Future<FileUpload?> pickFile() async => next;

  @override
  Future<FileUpload?> takePhoto() async {
    photos++;
    return next;
  }
}

void main() {
  late FakePicker picker;

  Future<void> openApp(WidgetTester tester, {String lang = 'fr', bool camera = false}) async {
    await configureDependencies(
      env: const Env(apiUrl: 'http://test', useMock: true),
      registerRepositories: registerMockRepositories,
    );
    picker = FakePicker(canUseCamera: camera);
    sl
      ..unregister<DocumentPicker>()
      ..registerSingleton<DocumentPicker>(picker);
    sl<LanguageCubit>().select(Locale(lang));
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(KabangutsiApp(router: buildCustomerRouter(), title: (l) => l.appTitleCustomer));
    await tester.pumpAndSettle();
  }

  Future<void> openScannerFromServices(WidgetTester tester, String servicesLabel, String scanLabel) async {
    await tester.tap(find.text(servicesLabel).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(scanLabel));
    await tester.pumpAndSettle();
  }

  testWidgets('services → scan: CNI photo read, fields shown, "to be checked" badge and time', (tester) async {
    await openApp(tester, lang: 'en');
    await openScannerFromServices(tester, 'Services', 'Scan a document');
    expect(find.byKey(const Key('doc_camera')), findsNothing); // web / desktop: file only

    await tester.tap(find.byKey(const Key('doc_type_cni')));
    picker.next = jpeg();
    await tester.tap(find.byKey(const Key('doc_file')));
    await tester.pumpAndSettle();
    expect(find.text('cni.jpg'), findsOneWidget);

    await tester.tap(find.byKey(const Key('doc_send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('doc_result')), findsOneWidget);
    expect(find.text('Detected type: National ID card'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('NIYONZIMA Claudine'), findsOneWidget);
    expect(find.text('To be checked'), findsOneWidget); // only id_number
    expect(
      find.descendant(of: find.byKey(const Key('doc_field_id_number')), matching: find.text('To be checked')),
      findsOneWidget,
    );
    expect(find.textContaining(RegExp(r'^Read in \d+\.\d s$')), findsOneWidget);
    // Not from a chat: no handoff promise, just "check them".
    expect(find.textContaining('Check them before using them'), findsOneWidget);

    await tester.tap(find.byKey(const Key('doc_another')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('doc_send')), findsOneWidget);
  });

  testWidgets('a PDF is explained in Kirundi and never sent', (tester) async {
    await openApp(tester, lang: 'rn');
    await openScannerFromServices(tester, 'Serivisi', 'Gusikana urupapuro');
    picker.next = pdf();
    await tester.tap(find.byKey(const Key('doc_file')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ubu dushobora gusoma amafoto y\'impapuro gusa'), findsOneWidget);
    final send = tester.widget<ButtonStyleButton>(find.byKey(const Key('doc_send')));
    expect(send.onPressed, isNull);
  });

  testWidgets('OCR service down (503) → "not available right now", in French', (tester) async {
    await openApp(tester, lang: 'fr', camera: true);
    await openScannerFromServices(tester, 'Services', 'Scanner un document');
    picker.next = jpeg('ocr-down.jpg');
    await tester.tap(find.byKey(const Key('doc_camera')));
    await tester.pumpAndSettle();
    expect(picker.photos, 1);
    await tester.tap(find.byKey(const Key('doc_send')));
    await tester.pumpAndSettle();
    expect(find.text("La lecture de documents n'est pas disponible pour le moment."), findsOneWidget);
    // The photo stays, so the customer can retry.
    expect(find.text('ocr-down.jpg'), findsOneWidget);
  });

  testWidgets('from the chat: field to check → agent review notice, chat waits for the agent', (tester) async {
    await openApp(tester, lang: 'en');
    await tester.tap(find.byKey(const Key('chat_scan_document')));
    await tester.pumpAndSettle();
    picker.next = jpeg();
    await tester.tap(find.byKey(const Key('doc_file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('doc_send')));
    await tester.pumpAndSettle();
    const notice = 'Some details must be checked: an agent will review this document and reply in this chat.';
    expect(find.text(notice), findsOneWidget);

    await tester.pageBack();
    // The chat now shows its animated "waiting for an agent" state: it never settles.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final chat = tester.element(find.byKey(const Key('chat_input'))).read<ChatBloc>();
    expect(chat.state.handoff, HandoffStatus.waiting);
    expect(chat.state.messages.last.text, notice);
    expect(sl<MockBackend>().detail(chat.state.conversationId!).call.handoffReason, 'agent_review');
    await tester.pumpWidget(const SizedBox()); // stop the chat's timers
    sl<MockBackend>().dispose();
  });

  testWidgets('complaint page opens the scanner with "complaint photo" selected', (tester) async {
    await openApp(tester, lang: 'en');
    await openScannerFromServices(tester, 'Services', 'Make a complaint');
    await tester.ensureVisible(find.byKey(const Key('complaint_scan_document')));
    await tester.tap(find.byKey(const Key('complaint_scan_document')));
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(find.byKey(const Key('doc_type_complaint_photo')));
    expect(chip.selected, isTrue);
  });
}
