import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/locale/language_cubit.dart';
import '../../../core/widgets/language_menu.dart';
import '../bloc/ussd_cubit.dart';

class UssdPage extends StatelessWidget {
  const UssdPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UssdCubit(sl()),
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.ussdTitle), actions: const [LanguageMenu()]),
        body: const UssdView(),
      ),
    );
  }
}

/// A feature-phone-like screen + keypad.
class UssdView extends StatefulWidget {
  const UssdView({super.key});

  @override
  State<UssdView> createState() => _UssdViewState();
}

class _UssdViewState extends State<UssdView> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String get _lang => context.read<LanguageCubit>().state.languageCode;

  void _press(String key) => setState(() => _input.text += key);

  void _backspace() {
    final t = _input.text;
    if (t.isNotEmpty) setState(() => _input.text = t.substring(0, t.length - 1));
  }

  void _send(UssdState state) {
    final cubit = context.read<UssdCubit>();
    final text = _input.text;
    _input.clear();
    if (state.inSession) {
      cubit.reply(text, lang: _lang);
    } else {
      cubit.dial(text, lang: _lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocBuilder<UssdCubit, UssdState>(
      builder: (context, state) {
        final cubit = context.read<UssdCubit>();
        final screen = switch (state.phase) {
          UssdPhase.idle => l10n.ussdDialHint,
          UssdPhase.loading => state.screen.isEmpty ? l10n.ussdRunning : state.screen,
          UssdPhase.menu => state.screen,
          UssdPhase.ended => state.screen.isEmpty ? l10n.ussdEnded : '${state.screen}\n\n— ${l10n.ussdEnded} —',
          UssdPhase.invalidCode => l10n.ussdInvalidCode,
          UssdPhase.error => l10n.ussdErrNetwork,
        };
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF263238), borderRadius: BorderRadius.circular(28)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const Key('ussd_screen'),
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFDCEDC8), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.phase == UssdPhase.loading) const LinearProgressIndicator(minHeight: 2),
                        Text(
                          screen,
                          style: const TextStyle(fontFamily: 'LiberationMono', fontSize: 15, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('ussd_input'),
                          controller: _input,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9*#]'))],
                          style: const TextStyle(fontFamily: 'LiberationMono', fontSize: 18, color: Colors.black),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white70,
                            hintText: state.inSession ? l10n.ussdInputHint : '*123#',
                          ),
                          onSubmitted: (_) => _send(state),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final row in const [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['*', '0', '#'],
                  ])
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final k in row)
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: SizedBox(
                              width: 72,
                              height: 44,
                              child: FilledButton.tonal(
                                onPressed: () => _press(k),
                                child: Text(k, style: const TextStyle(fontSize: 20)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton.filled(
                        key: const Key('ussd_cancel'),
                        tooltip: l10n.ussdCancel,
                        style: IconButton.styleFrom(backgroundColor: theme.colorScheme.error),
                        onPressed: () {
                          _input.clear();
                          cubit.cancel();
                        },
                        icon: const Icon(Icons.call_end),
                      ),
                      IconButton.filled(
                        key: const Key('ussd_send'),
                        tooltip: state.inSession ? l10n.ussdSend : l10n.ussdDial,
                        style: IconButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: state.phase == UssdPhase.loading ? null : () => _send(state),
                        icon: Icon(state.inSession ? Icons.send : Icons.call),
                      ),
                      IconButton.filledTonal(
                        tooltip: '⌫',
                        onPressed: _backspace,
                        icon: const Icon(Icons.backspace_outlined),
                      ),
                    ],
                  ),
                  if (state.phase == UssdPhase.ended) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _input.text = UssdCubit.code;
                        _send(const UssdState());
                      },
                      child: Text(l10n.ussdDialAgain, style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
