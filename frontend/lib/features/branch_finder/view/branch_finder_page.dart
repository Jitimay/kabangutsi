import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/locale/language_cubit.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../data/models/models.dart';
import '../bloc/branch_finder_cubit.dart';

class BranchFinderPage extends StatelessWidget {
  const BranchFinderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageCubit>().state.languageCode;
    return BlocProvider(
      create: (_) => BranchFinderCubit(sl())..load(lang),
      child: BlocListener<LanguageCubit, Locale>(
        // hours_text is localized by the backend.
        listener: (context, l) => context.read<BranchFinderCubit>().load(l.languageCode),
        child: Scaffold(
          appBar: AppBar(title: Text(context.l10n.branchFinderTitle), actions: const [LanguageMenu()]),
          body: const BranchFinderView(),
        ),
      ),
    );
  }
}

class BranchFinderView extends StatelessWidget {
  const BranchFinderView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<BranchFinderCubit, BranchFinderState>(
      builder: (context, state) {
        final cubit = context.read<BranchFinderCubit>();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      key: const Key('branch_search'),
                      decoration: InputDecoration(labelText: l10n.branchSearch, prefixIcon: const Icon(Icons.search)),
                      onChanged: cubit.search,
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String?>(
                      key: const Key('branch_province'),
                      initialValue: state.province,
                      decoration: InputDecoration(labelText: l10n.branchProvince),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.branchAllProvinces)),
                        for (final p in state.provinces) DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: cubit.selectProvince,
                    ),
                  ),
                ],
              ),
            ),
            if (state.status == BranchStatus.loading) const LinearProgressIndicator(),
            Expanded(child: _body(context, state, cubit)),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, BranchFinderState state, BranchFinderCubit cubit) {
    final l10n = context.l10n;
    if (state.status == BranchStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.branchErrLoad),
            const SizedBox(height: 8),
            FilledButton(onPressed: cubit.retry, child: Text(l10n.branchRetry)),
          ],
        ),
      );
    }
    if (state.status == BranchStatus.ready && state.branches.isEmpty) return Center(child: Text(l10n.branchEmpty));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: state.branches.length,
      itemBuilder: (context, i) => _BranchCard(branch: state.branches[i]),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.branch});

  final Branch branch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final b = branch;
    final open = b.isOpenNow;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        shape: const Border(),
        title: Row(
          children: [
            Expanded(child: Text(b.name, style: theme.textTheme.titleMedium)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: open ? Colors.green.withValues(alpha: 0.15) : theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                open ? l10n.branchOpenNow : l10n.branchClosedNow,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: open ? Colors.green.shade800 : theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${b.town} · ${b.province}'),
            Text(b.hoursText, style: theme.textTheme.bodySmall),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(b.address)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 18),
              const SizedBox(width: 6),
              SelectableText(formatPhone(b.phone)),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.branchHours, style: theme.textTheme.titleSmall),
          for (final d in kWeekDays)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  SizedBox(width: 140, child: Text(_day(l10n, d))),
                  Text(b.hours[d] == null ? l10n.branchDayClosed : '${b.hours[d]!.open} – ${b.hours[d]!.close}'),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final s in b.services) Chip(label: Text(_service(l10n, s)), visualDensity: VisualDensity.compact),
            ],
          ),
        ],
      ),
    );
  }

  static String _day(AppLocalizations l10n, String d) => switch (d) {
    'mon' => l10n.branchDayMon,
    'tue' => l10n.branchDayTue,
    'wed' => l10n.branchDayWed,
    'thu' => l10n.branchDayThu,
    'fri' => l10n.branchDayFri,
    'sat' => l10n.branchDaySat,
    _ => l10n.branchDaySun,
  };

  static String _service(AppLocalizations l10n, String s) => switch (s) {
    'cash' => l10n.branchSvcCash,
    'accounts' => l10n.branchSvcAccounts,
    'loans' => l10n.branchSvcLoans,
    'cards' => l10n.branchSvcCards,
    'atm' => l10n.branchSvcAtm,
    'forex' => l10n.branchSvcForex,
    'mobile_banking' => l10n.branchSvcMobileBanking,
    _ => s,
  };
}
