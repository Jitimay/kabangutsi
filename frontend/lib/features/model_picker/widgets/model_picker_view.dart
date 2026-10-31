import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/l10n.dart';
import '../../../data/models/models.dart';
import '../bloc/model_picker_cubit.dart';
import 'capability_badge.dart';

/// List of installed models with capability badges (F19). Needs a [ModelPickerCubit] above.
class ModelPickerView extends StatelessWidget {
  const ModelPickerView({super.key, this.onSelected, this.shrinkWrap = false});

  final VoidCallback? onSelected;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<ModelPickerCubit, ModelPickerState>(
      listenWhen: (a, b) => b.error != null && a.error != b.error && b.status == ModelPickerStatus.ready,
      listener: (context, state) => ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(state.error!.message.isEmpty ? l10n.modelLoadFailed : state.error!.message))),
      builder: (context, state) {
        final cubit = context.read<ModelPickerCubit>();
        if (state.status == ModelPickerStatus.loading && state.models.isEmpty ||
            state.status == ModelPickerStatus.initial) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.status == ModelPickerStatus.failure && state.models.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.modelLoadFailed, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => cubit.load(refresh: true),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.modelPickerRefresh),
                ),
              ],
            ),
          );
        }
        if (state.models.isEmpty) {
          return Padding(padding: const EdgeInsets.all(24), child: Text(l10n.modelNone));
        }
        return ListView.separated(
          shrinkWrap: shrinkWrap,
          padding: const EdgeInsets.all(12),
          itemCount: state.models.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _ModelTile(
            model: state.models[i],
            selected: state.models[i].name == state.effective,
            isDefault: state.models[i].name == state.defaultModel,
            onTap: state.models[i].selectable && !state.updating
                ? () {
                    cubit.select(state.models[i].name);
                    onSelected?.call();
                  }
                : null,
          ),
        );
      },
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.model, required this.selected, required this.isDefault, this.onTap});

  final LlmModel model;
  final bool selected;
  final bool isDefault;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final details = [model.parameterSize, model.quantization].whereType<String>().join(' · ');
    return Card(
      key: Key('model_${model.name}'),
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: onTap == null && !selected ? theme.disabledColor : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(model.name, style: theme.textTheme.titleMedium)),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Text(l10n.modelDefaultBadge,
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                        ],
                      ],
                    ),
                    if (details.isNotEmpty) Text(details, style: theme.textTheme.bodySmall),
                    if (!model.selectable)
                      Text(l10n.modelNotSelectable,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final c in model.capabilities) CapabilityBadge(c)],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the picker as a bottom sheet, sharing the given cubit.
Future<void> showModelPickerSheet(BuildContext context, ModelPickerCubit cubit) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => BlocProvider.value(
      value: cubit,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(sheetContext.l10n.modelPickerTitle, style: Theme.of(sheetContext).textTheme.titleLarge),
                trailing: IconButton(
                  tooltip: sheetContext.l10n.modelPickerRefresh,
                  icon: const Icon(Icons.refresh),
                  onPressed: () => cubit.load(refresh: true),
                ),
              ),
              Flexible(
                child: ModelPickerView(shrinkWrap: true, onSelected: () => Navigator.of(sheetContext).pop()),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
