import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

enum CardBlockStep { form, verifying, confirm, confirming, done, locked }

enum CardBlockFailure { identityFailed, expired, notFound, network, chooseCard, generic }

/// F5 state. Never contains the PIN or the date of birth: they are passed to
/// [CardBlockCubit.verify] and forwarded to the repository only.
class CardBlockState extends Equatable {
  const CardBlockState({
    this.step = CardBlockStep.form,
    this.useDateOfBirth = false,
    this.reason = 'lost',
    this.pending,
    this.result,
    this.failure,
    this.attemptsLeft,
    this.cardChoices = const [],
  });

  final CardBlockStep step;
  final bool useDateOfBirth;
  final String reason;
  final CardBlockPending? pending;
  final CardBlockResult? result;
  final CardBlockFailure? failure;
  final int? attemptsLeft;

  /// Last 4 digits offered when the customer has several active cards (422 `details.cards`).
  final List<String> cardChoices;

  CardBlockState copyWith({
    CardBlockStep? step,
    bool? useDateOfBirth,
    String? reason,
    CardBlockPending? Function()? pending,
    CardBlockResult? Function()? result,
    CardBlockFailure? Function()? failure,
    int? Function()? attemptsLeft,
    List<String>? cardChoices,
  }) => CardBlockState(
    step: step ?? this.step,
    useDateOfBirth: useDateOfBirth ?? this.useDateOfBirth,
    reason: reason ?? this.reason,
    pending: pending != null ? pending() : this.pending,
    result: result != null ? result() : this.result,
    failure: failure != null ? failure() : this.failure,
    attemptsLeft: attemptsLeft != null ? attemptsLeft() : this.attemptsLeft,
    cardChoices: cardChoices ?? this.cardChoices,
  );

  @override
  List<Object?> get props => [step, useDateOfBirth, reason, pending, result, failure, attemptsLeft, cardChoices];
}

class CardBlockCubit extends Cubit<CardBlockState> {
  CardBlockCubit(this._repo, {this.conversationId}) : super(const CardBlockState());

  final CardRepository _repo;
  final String? conversationId;

  void toggleDateOfBirth(bool useDob) => emit(state.copyWith(useDateOfBirth: useDob, failure: () => null));

  void selectReason(String reason) => emit(state.copyWith(reason: reason));

  /// Step 1: identity check in code (backend). [secret] is the PIN or the
  /// date of birth (YYYY-MM-DD) depending on [CardBlockState.useDateOfBirth].
  Future<void> verify({
    required String accountNumber,
    required String secret,
    String? cardLast4,
    required String lang,
  }) async {
    if (state.step == CardBlockStep.verifying || state.step == CardBlockStep.locked) return;
    emit(state.copyWith(step: CardBlockStep.verifying, failure: () => null));
    final dob = state.useDateOfBirth;
    try {
      final pending = await _repo.verify(
        CardBlockRequest(
          conversationId: conversationId,
          accountNumber: accountNumber,
          pin: dob ? null : secret,
          dateOfBirth: dob ? secret : null,
          cardLast4: (cardLast4 == null || cardLast4.isEmpty) ? null : cardLast4,
          reason: state.reason,
          lang: lang,
        ),
      );
      emit(state.copyWith(step: CardBlockStep.confirm, pending: () => pending, attemptsLeft: () => null, cardChoices: const []));
    } on ApiError catch (e) {
      _fail(e);
    }
  }

  /// Step 2: confirm and block.
  Future<void> confirm() async {
    final pending = state.pending;
    if (pending == null || state.step != CardBlockStep.confirm) return;
    emit(state.copyWith(step: CardBlockStep.confirming, failure: () => null));
    try {
      final result = await _repo.confirm(pending.confirmationId);
      emit(state.copyWith(step: CardBlockStep.done, result: () => result, pending: () => null));
    } on ApiError catch (e) {
      _fail(e);
    }
  }

  /// Back to an empty form (cancel, expired, block another card).
  void restart() => emit(CardBlockState(useDateOfBirth: state.useDateOfBirth));

  void _fail(ApiError e) {
    if (e.status == 423 || e.code == 'locked') {
      emit(state.copyWith(step: CardBlockStep.locked, pending: () => null, failure: () => null));
      return;
    }
    final cards = e.details['cards'];
    if (e.status == 422 && cards is List && cards.isNotEmpty) {
      emit(state.copyWith(
        step: CardBlockStep.form,
        failure: () => CardBlockFailure.chooseCard,
        cardChoices: [for (final c in cards) '$c'],
        pending: () => null,
      ));
      return;
    }
    final (failure, step) = switch (e) {
      ApiError(code: 'identity_failed') ||
      ApiError(status: 403) => (CardBlockFailure.identityFailed, CardBlockStep.form),
      ApiError(code: 'expired') || ApiError(status: 410) => (CardBlockFailure.expired, CardBlockStep.form),
      ApiError(status: 404) || ApiError(code: 'not_found') => (CardBlockFailure.notFound, CardBlockStep.form),
      ApiError(code: 'network_error') => (
        CardBlockFailure.network,
        state.pending != null ? CardBlockStep.confirm : CardBlockStep.form,
      ),
      _ => (CardBlockFailure.generic, state.pending != null ? CardBlockStep.confirm : CardBlockStep.form),
    };
    final attempts = e.details['attempts_left'];
    emit(
      state.copyWith(
        step: step,
        failure: () => failure,
        attemptsLeft: () => attempts is int ? attempts : null,
        pending: step == CardBlockStep.form ? () => null : null,
      ),
    );
  }
}
