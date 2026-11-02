import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

enum ComplaintStatus { editing, submitting, success, failure }

enum ComplaintFailure { upload, generic }

/// F7 state.
class ComplaintState extends Equatable {
  const ComplaintState({
    this.status = ComplaintStatus.editing,
    this.category = 'other',
    this.urgency = 'medium',
    this.photo,
    this.ticket,
    this.failure,
    this.error,
  });

  final ComplaintStatus status;
  final String category;
  final String urgency;
  final FileUpload? photo;
  final Ticket? ticket;
  final ComplaintFailure? failure;
  final ApiError? error;

  ComplaintState copyWith({
    ComplaintStatus? status,
    String? category,
    String? urgency,
    FileUpload? Function()? photo,
    Ticket? Function()? ticket,
    ComplaintFailure? Function()? failure,
    ApiError? Function()? error,
  }) => ComplaintState(
    status: status ?? this.status,
    category: category ?? this.category,
    urgency: urgency ?? this.urgency,
    photo: photo != null ? photo() : this.photo,
    ticket: ticket != null ? ticket() : this.ticket,
    failure: failure != null ? failure() : this.failure,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [status, category, urgency, photo, ticket, failure, error];
}

class ComplaintCubit extends Cubit<ComplaintState> {
  ComplaintCubit(this._tickets, this._files, {this.conversationId}) : super(const ComplaintState());

  final TicketRepository _tickets;
  final FileRepository _files;
  final String? conversationId;

  static final phonePattern = RegExp(r'^\+257\d{8}$');

  void selectCategory(String c) => emit(state.copyWith(category: c));
  void selectUrgency(String u) => emit(state.copyWith(urgency: u));
  void setPhoto(FileUpload? photo) => emit(state.copyWith(photo: () => photo));

  /// Uploads the optional photo, then creates the ticket.
  Future<void> submit({required String description, String? phone, required String lang}) async {
    if (state.status == ComplaintStatus.submitting) return;
    emit(state.copyWith(status: ComplaintStatus.submitting, failure: () => null, error: () => null));
    final attachments = <Attachment>[];
    if (state.photo != null) {
      try {
        final ref = await _files.upload(state.photo!);
        attachments.add(ref.toAttachment(name: state.photo!.filename));
      } on ApiError catch (e) {
        emit(state.copyWith(status: ComplaintStatus.failure, failure: () => ComplaintFailure.upload, error: () => e));
        return;
      }
    }
    try {
      final ticket = await _tickets.create(
        TicketCreate(
          conversationId: conversationId,
          phone: (phone == null || phone.isEmpty) ? null : phone,
          category: state.category,
          urgency: state.urgency,
          description: description.trim(),
          lang: lang,
          attachments: attachments,
        ),
      );
      emit(state.copyWith(status: ComplaintStatus.success, ticket: () => ticket));
    } on ApiError catch (e) {
      emit(state.copyWith(status: ComplaintStatus.failure, failure: () => ComplaintFailure.generic, error: () => e));
    }
  }

  void reset() => emit(const ComplaintState());
}
