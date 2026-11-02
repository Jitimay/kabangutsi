part of 'chat_bloc.dart';

sealed class ChatEvent {
  const ChatEvent();
}

/// Opens a conversation (`channel: web`) in the UI language with the chosen model.
class ChatStarted extends ChatEvent {
  const ChatStarted({required this.lang, this.model});
  final String lang;
  final String? model;
}

/// Ends nothing on the server: starts a fresh conversation after end_session.
class ChatRestarted extends ChatEvent {
  const ChatRestarted({required this.lang});
  final String lang;
}

/// Text from the input field. May be a PIN / date of birth when the backend
/// asked for one: [toString] never prints it.
class ChatTextSent extends ChatEvent {
  const ChatTextSent(this.text);
  final String text;

  @override
  String toString() => 'ChatTextSent(••••)';
}

class ChatImageSent extends ChatEvent {
  const ChatImageSent(this.image, {this.text});
  final FileUpload image;
  final String? text;
}

class ChatModelChanged extends ChatEvent {
  const ChatModelChanged(this.model);
  final String? model;
}

class ChatHandoffRequested extends ChatEvent {
  const ChatHandoffRequested();
}

class _ChatLiveEvent extends ChatEvent {
  const _ChatLiveEvent(this.event);
  final WsEvent event;
}
