import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/locale/language_cubit.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../data/models/models.dart';
import '../bloc/card_block_cubit.dart';
import '../widgets/card_block_labels.dart';

class CardBlockPage extends StatelessWidget {
  const CardBlockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CardBlockCubit(sl()),
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.cardBlockTitle), actions: const [LanguageMenu()]),
        body: const CardBlockView(),
      ),
    );
  }
}

class CardBlockView extends StatelessWidget {
  const CardBlockView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CardBlockCubit, CardBlockState>(
      builder: (context, state) {
        final child = switch (state.step) {
          CardBlockStep.form || CardBlockStep.verifying => const _IdentityForm(),
          CardBlockStep.confirm || CardBlockStep.confirming => _ConfirmStep(state: state),
          CardBlockStep.done => _DoneStep(result: state.result!),
          CardBlockStep.locked => const _LockedStep(),
        };
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.all(16), children: [child]),
          ),
        );
      },
    );
  }
}

class _IdentityForm extends StatefulWidget {
  const _IdentityForm();

  @override
  State<_IdentityForm> createState() => _IdentityFormState();
}

class _IdentityFormState extends State<_IdentityForm> {
  final _formKey = GlobalKey<FormState>();
  final _account = TextEditingController();
  final _pin = TextEditingController();
  final _last4 = TextEditingController();

  /// Kept in the widget only (never in the BLoC state), cleared after submit.
  DateTime? _dob;

  @override
  void dispose() {
    _account.dispose();
    _pin.dispose();
    _last4.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _submit(CardBlockState state) {
    if (!_formKey.currentState!.validate()) return;
    final String secret;
    if (state.useDateOfBirth) {
      final d = _dob!;
      secret =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } else {
      secret = _pin.text;
    }
    // Clear the secret from the UI right away.
    _pin.clear();
    setState(() => _dob = null);
    context.read<CardBlockCubit>().verify(
      accountNumber: _account.text.trim(),
      secret: secret,
      cardLast4: _last4.text.trim(),
      lang: context.read<LanguageCubit>().state.languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CardBlockCubit>().state;
    final cubit = context.read<CardBlockCubit>();
    final busy = state.step == CardBlockStep.verifying;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.failure != null) ...[
            _ErrorBanner(text: cardFailureText(l10n, state.failure!, state.attemptsLeft)),
            const SizedBox(height: 12),
          ],
          TextFormField(
            key: const Key('card_account'),
            controller: _account,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
            decoration: InputDecoration(
              labelText: l10n.cardAccountNumber,
              prefixIcon: const Icon(Icons.account_balance_outlined),
            ),
            validator: (v) => RegExp(r'^\d{11}$').hasMatch(v ?? '') ? null : l10n.cardAccountNumberError,
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l10n.cardUsePin), icon: const Icon(Icons.pin_outlined)),
              ButtonSegment(value: true, label: Text(l10n.cardUseDob), icon: const Icon(Icons.cake_outlined)),
            ],
            selected: {state.useDateOfBirth},
            onSelectionChanged: busy ? null : (s) => cubit.toggleDateOfBirth(s.first),
          ),
          const SizedBox(height: 16),
          if (!state.useDateOfBirth)
            TextFormField(
              key: const Key('card_pin'),
              controller: _pin,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              decoration: InputDecoration(labelText: l10n.cardPin, prefixIcon: const Icon(Icons.lock_outline)),
              validator: (v) => RegExp(r'^\d{4}$').hasMatch(v ?? '') ? null : l10n.cardFourDigitsError,
            )
          else
            FormField<DateTime>(
              validator: (_) => _dob == null ? l10n.cardDobError : null,
              builder: (field) => OutlinedButton.icon(
                key: const Key('card_dob'),
                onPressed: busy ? null : _pickDob,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  _dob == null
                      ? (field.hasError ? field.errorText! : l10n.cardDobPick)
                      : MaterialLocalizations.of(context).formatMediumDate(_dob!),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (state.cardChoices.isNotEmpty) ...[
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in state.cardChoices)
                ChoiceChip(
                  key: Key('card_choice_$c'),
                  avatar: const Icon(Icons.credit_card, size: 18),
                  label: Text(l10n.cardEnding(c)),
                  selected: _last4.text == c,
                  onSelected: busy ? null : (_) => setState(() => _last4.text = c),
                ),
            ]),
            const SizedBox(height: 16),
          ],
          TextFormField(
            key: const Key('card_last4'),
            controller: _last4,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: InputDecoration(labelText: l10n.cardLast4, prefixIcon: const Icon(Icons.credit_card)),
            validator: (v) =>
                (v == null || v.isEmpty || RegExp(r'^\d{4}$').hasMatch(v)) ? null : l10n.cardFourDigitsError,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: state.reason,
            decoration: InputDecoration(labelText: l10n.cardReason),
            items: [
              for (final r in kCardBlockReasons) DropdownMenuItem(value: r, child: Text(cardReasonLabel(l10n, r))),
            ],
            onChanged: busy ? null : (r) => cubit.selectReason(r!),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.cardSecurityNote, style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('card_verify'),
            onPressed: busy ? null : () => _submit(state),
            icon: busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.verified_user_outlined),
            label: Text(l10n.cardVerify),
          ),
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({required this.state});

  final CardBlockState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pending = state.pending!;
    final cubit = context.read<CardBlockCubit>();
    final busy = state.step == CardBlockStep.confirming;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.cardConfirmTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.credit_card, size: 36),
            title: Text(l10n.cardEnding(pending.card.last4)),
            subtitle: Text(cardTypeLabel(l10n, pending.card.type)),
          ),
        ),
        const SizedBox(height: 12),
        Text(pending.message, style: Theme.of(context).textTheme.bodyLarge),
        if (state.failure != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(text: cardFailureText(l10n, state.failure!, state.attemptsLeft)),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('card_confirm'),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: busy ? null : cubit.confirm,
          icon: busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.block),
          label: Text(l10n.cardConfirm),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: busy ? null : cubit.restart, child: Text(l10n.cardCancel)),
      ],
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.result});

  final CardBlockResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 8),
        Text(l10n.cardBlockedTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text(l10n.cardReference, textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
        SelectableText(
          result.reference,
          key: const Key('card_reference'),
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Text(l10n.cardEnding(result.card.last4), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text(result.message, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: context.read<CardBlockCubit>().restart, child: Text(l10n.cardBlockAnother)),
      ],
    );
  }
}

class _LockedStep extends StatelessWidget {
  const _LockedStep();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(Icons.support_agent, size: 64, color: theme.colorScheme.error),
        const SizedBox(height: 12),
        Text(
          context.l10n.cardErrLocked,
          key: const Key('card_locked'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              key: const Key('card_error'),
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
