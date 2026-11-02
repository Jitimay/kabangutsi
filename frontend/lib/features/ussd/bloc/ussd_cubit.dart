import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/util/format.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

enum UssdPhase { idle, loading, menu, ended, invalidCode, error }

/// F14 (UI) state of the USSD simulator.
class UssdState extends Equatable {
  const UssdState({this.phase = UssdPhase.idle, this.screen = '', this.sessionId, this.expectedInput = 'menu_choice'});

  final UssdPhase phase;

  /// Menu screen text from the backend (`OutgoingReply.text`).
  final String screen;
  final String? sessionId;

  /// `expected_input` of the last reply: `text` means a free question (letters allowed).
  final String expectedInput;

  bool get expectsText => inSession && expectedInput == 'text';

  bool get inSession => sessionId != null && (phase == UssdPhase.menu || phase == UssdPhase.loading);

  @override
  List<Object?> get props => [phase, screen, sessionId, expectedInput];
}

class UssdCubit extends Cubit<UssdState> {
  UssdCubit(this._repo, {this.phone = demoPhone, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const UssdState());

  static const code = '*123#';

  /// Fictional demo number (scripts/seed).
  static const demoPhone = '+25779000103';

  final UssdRepository _repo;
  final String phone;
  final DateTime Function() _clock;

  /// Starts a session when [dialed] is `*123#` (initial message text is "").
  Future<void> dial(String dialed, {required String lang}) async {
    if (dialed.replaceAll(' ', '') != code) {
      emit(const UssdState(phase: UssdPhase.invalidCode));
      return;
    }
    final session = 'ussd-${uuidV4().substring(0, 8)}';
    await _send(session, '', lang);
  }

  /// Sends a menu choice in the current session.
  Future<void> reply(String input, {required String lang}) async {
    final session = state.sessionId;
    if (session == null || state.phase != UssdPhase.menu || input.trim().isEmpty) return;
    await _send(session, input.trim(), lang);
  }

  void cancel() => emit(const UssdState());

  Future<void> _send(String session, String text, String lang) async {
    emit(UssdState(phase: UssdPhase.loading, screen: state.screen, sessionId: session, expectedInput: state.expectedInput));
    try {
      final r = await _repo.send(
        InboundMessage(
          id: uuidV4(),
          channel: 'ussd',
          phone: phone,
          sessionId: session,
          lang: lang,
          text: text,
          ts: _clock().toUtc(),
        ),
      );
      emit(
        UssdState(
          phase: r.endSession ? UssdPhase.ended : UssdPhase.menu,
          screen: r.text,
          sessionId: r.endSession ? null : session,
          expectedInput: r.expectedInput,
        ),
      );
    } on ApiError {
      emit(const UssdState(phase: UssdPhase.error));
    }
  }
}
