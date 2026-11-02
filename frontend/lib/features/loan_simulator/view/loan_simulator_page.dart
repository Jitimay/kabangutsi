import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/locale/language_cubit.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../data/models/models.dart';
import '../bloc/loan_simulator_cubit.dart';

class LoanSimulatorPage extends StatelessWidget {
  const LoanSimulatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageCubit>().state.languageCode;
    return BlocProvider(
      create: (_) => LoanSimulatorCubit(sl())..load(lang),
      child: BlocListener<LanguageCubit, Locale>(
        // Product names and requirements are localized by the backend.
        listener: (context, locale) => context.read<LoanSimulatorCubit>().load(locale.languageCode),
        child: Scaffold(
          appBar: AppBar(title: Text(context.l10n.loanSimulatorTitle), actions: const [LanguageMenu()]),
          body: const LoanSimulatorView(),
        ),
      ),
    );
  }
}

class LoanSimulatorView extends StatefulWidget {
  const LoanSimulatorView({super.key});

  @override
  State<LoanSimulatorView> createState() => _LoanSimulatorViewState();
}

class _LoanSimulatorViewState extends State<LoanSimulatorView> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _term = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _term.dispose();
    super.dispose();
  }

  void _simulate() {
    if (!_formKey.currentState!.validate()) return;
    context.read<LoanSimulatorCubit>().simulate(
      amount: int.parse(_amount.text),
      termMonths: int.parse(_term.text),
      lang: context.read<LanguageCubit>().state.languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocBuilder<LoanSimulatorCubit, LoanSimulatorState>(
      builder: (context, state) {
        final cubit = context.read<LoanSimulatorCubit>();
        if (state.status == LoanStatus.loading) return const Center(child: CircularProgressIndicator());
        if (state.status == LoanStatus.loadError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.loanErrLoad),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => cubit.load(context.read<LanguageCubit>().state.languageCode),
                  child: Text(l10n.loanRetry),
                ),
              ],
            ),
          );
        }
        final p = state.selected;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    key: const Key('loan_product'),
                    initialValue: p?.id,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.loanProduct),
                    items: [for (final x in state.products) DropdownMenuItem(value: x.id, child: Text(x.name))],
                    onChanged: (id) => cubit.select(state.products.firstWhere((x) => x.id == id)),
                  ),
                  if (p != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.description),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.percent, size: 16),
                                  label: Text(l10n.loanRate(_rate(p.annualRatePct))),
                                ),
                                Chip(label: Text(l10n.loanAmountRange(formatFbu(p.minAmount), formatFbu(p.maxAmount)))),
                                Chip(label: Text(l10n.loanTermRange('${p.minTermMonths}', '${p.maxTermMonths}'))),
                              ],
                            ),
                            if (p.requirements.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(l10n.loanRequirements, style: theme.textTheme.titleSmall),
                              for (final r in p.requirements)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('•  '),
                                      Expanded(child: Text(r)),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('loan_amount'),
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: l10n.loanAmount, suffixText: 'FBu'),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return (n == null || n < p.minAmount || n > p.maxAmount)
                            ? l10n.loanAmountError(formatFbu(p.minAmount), formatFbu(p.maxAmount))
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('loan_term'),
                      controller: _term,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: l10n.loanTerm),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return (n == null || n < p.minTermMonths || n > p.maxTermMonths)
                            ? l10n.loanTermError('${p.minTermMonths}', '${p.maxTermMonths}')
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('loan_simulate'),
                      onPressed: state.simulating ? null : _simulate,
                      icon: state.simulating
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.calculate_outlined),
                      label: Text(l10n.loanSimulate),
                    ),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.error!.message.isNotEmpty ? state.error!.message : l10n.loanErrGeneric,
                      key: const Key('loan_error'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  if (state.simulation != null) ...[const SizedBox(height: 16), _Result(sim: state.simulation!)],
                  const SizedBox(height: 12),
                  Text(l10n.loanFictional, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _rate(double r) => r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
}

class _Result extends StatelessWidget {
  const _Result({required this.sim});

  final LoanSimulation sim;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget row(String label, int v, {bool big = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            formatFbu(v),
            style: big
                ? theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)
                : theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
    return Card(
      key: const Key('loan_result'),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(sim.productName, style: theme.textTheme.titleMedium),
            const Divider(),
            row(l10n.loanMonthly, sim.monthlyPayment, big: true),
            row(l10n.loanTotal, sim.totalPayment),
            row(l10n.loanInterest, sim.totalInterest),
            const SizedBox(height: 8),
            Text(sim.explanation, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
