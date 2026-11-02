import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/locale/language_cubit.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../model_picker/bloc/model_picker_cubit.dart';
import '../../model_picker/view/model_picker_session.dart';
import '../../model_picker/widgets/model_picker_view.dart';
import '../bloc/chat_bloc.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final picker = ModelPickerSession.cubit;
    final lang = context.read<LanguageCubit>().state.languageCode;
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: picker),
        BlocProvider(
          create: (_) => ChatBloc(sl<ConversationRepository>())
            ..add(ChatStarted(lang: lang, model: picker.state.selected)),
        ),
      ],
      child: const ChatView(),
    );
  }
}

/// Chat screen body; needs a [ChatBloc] and a [ModelPickerCubit] above.
class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  String _errorText(BuildContext context, ApiError e) {
    final l10n = context.l10n;
    if (e.code == 'network_error') return l10n.chatErrorNetwork;
    return e.message.isNotEmpty ? e.message : l10n.chatErrorGeneric;
  }

  Future<void> _confirmHandoff(BuildContext context) async {
    final l10n = context.l10n;
    final bloc = context.read<ChatBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.chatHandoffConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.chatCancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l10n.chatConfirm)),
        ],
      ),
    );
    if (ok ?? false) bloc.add(const ChatHandoffRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MultiBlocListener(
      listeners: [
        BlocListener<ModelPickerCubit, ModelPickerState>(
          listenWhen: (a, b) => a.selected != b.selected,
          listener: (context, s) => context.read<ChatBloc>().add(ChatModelChanged(s.selected)),
        ),
        BlocListener<ChatBloc, ChatState>(
          listenWhen: (a, b) => a.conversationId != b.conversationId,
          listener: (context, s) => context.read<ModelPickerCubit>().attachConversation(s.conversationId),
        ),
        BlocListener<ChatBloc, ChatState>(
          listenWhen: (a, b) => b.error != null && a.error != b.error && b.status == ChatStatus.ready,
          listener: (context, s) =>
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(context, s.error!)))),
        ),
        BlocListener<ChatBloc, ChatState>(
          listenWhen: (a, b) => a.messages != b.messages,
          listener: (_, _) => _scrollToEnd(),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navChat),
          actions: [
            BlocBuilder<ChatBloc, ChatState>(
              buildWhen: (a, b) => a.handoff != b.handoff || a.ended != b.ended || a.status != b.status,
              builder: (context, s) => IconButton(
                key: const Key('chat_handoff'),
                tooltip: l10n.talkToAgent,
                icon: const Icon(Icons.support_agent),
                onPressed: s.status == ChatStatus.ready && s.handoff == HandoffStatus.none && !s.ended
                    ? () => _confirmHandoff(context)
                    : null,
              ),
            ),
            IconButton(
              key: const Key('chat_model_picker'),
              tooltip: l10n.modelPickerTitle,
              icon: const Icon(Icons.psychology_outlined),
              onPressed: () => showModelPickerSheet(context, context.read<ModelPickerCubit>()),
            ),
            const LanguageMenu(),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: BlocBuilder<ModelPickerCubit, ModelPickerState>(
              builder: (context, s) => Container(
                height: 28,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  s.effective == null ? l10n.chatModelDefault : l10n.chatModelInUse(s.effective!),
                  key: const Key('chat_model_label'),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85)),
                ),
              ),
            ),
          ),
        ),
        body: BlocBuilder<ChatBloc, ChatState>(
          builder: (context, s) {
            final lang = context.read<LanguageCubit>().state.languageCode;
            final fallbackModel = context.select((ModelPickerCubit c) => c.state.effective);
            if (s.status == ChatStatus.initial || s.status == ChatStatus.starting) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(l10n.chatStarting),
                ]),
              );
            }
            if (s.status == ChatStatus.failure) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(l10n.chatStartFailed, textAlign: TextAlign.center),
                    if (s.error != null) Text(_errorText(context, s.error!), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => context.read<ChatBloc>().add(ChatRestarted(lang: lang)),
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.chatRetry),
                    ),
                  ]),
                ),
              );
            }
            return Column(
              children: [
                if (s.handoff == HandoffStatus.waiting || s.handoff == HandoffStatus.withAgent)
                  MaterialBanner(
                    key: const Key('chat_handoff_banner'),
                    leading: s.handoff == HandoffStatus.waiting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.support_agent),
                    content: Text(s.handoff == HandoffStatus.waiting ? l10n.chatWaitingAgent : l10n.chatWithAgent),
                    actions: const [SizedBox.shrink()],
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: s.messages.length,
                    itemBuilder: (_, i) => MessageBubble(
                      message: s.messages[i],
                      fallbackModel: fallbackModel,
                    ),
                  ),
                ),
                if (s.ended)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(l10n.chatSessionEnded),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          key: const Key('chat_new_conversation'),
                          onPressed: () => context.read<ChatBloc>().add(ChatRestarted(lang: lang)),
                          icon: const Icon(Icons.add_comment_outlined),
                          label: Text(l10n.chatNewConversation),
                        ),
                      ]),
                    ),
                  )
                else
                  ChatInputBar(
                    enabled: s.canSend,
                    secret: s.secretInput,
                    expectedInput: s.expectedInput,
                    onSend: (t) => context.read<ChatBloc>().add(ChatTextSent(t)),
                    onImage: (img, text) => context.read<ChatBloc>().add(ChatImageSent(img, text: text)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
