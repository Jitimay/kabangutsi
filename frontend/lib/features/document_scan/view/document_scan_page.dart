import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/locale/language_cubit.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../bloc/document_scan_cubit.dart';
import '../services/document_picker.dart';
import '../widgets/document_labels.dart';

/// F17: scan a document (services hub, chat input bar, complaint page).
///
/// From a chat, pass [conversationId]: if a field needs review the backend
/// hands the conversation to an agent and [onAgentReview] is called once.
class DocumentScanPage extends StatelessWidget {
  const DocumentScanPage({
    super.key,
    this.conversationId,
    this.initialDocType = kDocTypeAuto,
    this.onAgentReview,
    this.picker,
  });

  final String? conversationId;
  final String initialDocType;
  final VoidCallback? onAgentReview;
  /// Defaults to the registered [DocumentPicker] (camera / file dialog).
  final DocumentPicker? picker;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DocumentScanCubit(
        sl<DocumentRepository>(),
        conversationId: conversationId,
        initialDocType: initialDocType,
      ),
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.docScanTitle), actions: const [LanguageMenu()]),
        body: BlocListener<DocumentScanCubit, DocumentScanState>(
          listenWhen: (a, b) => a.status != b.status && b.status == DocScanStatus.done,
          listener: (context, _) {
            if (context.read<DocumentScanCubit>().agentReview) onAgentReview?.call();
          },
          child: DocumentScanView(picker: picker ?? sl<DocumentPicker>()),
        ),
      ),
    );
  }
}

class DocumentScanView extends StatelessWidget {
  const DocumentScanView({super.key, required this.picker});

  final DocumentPicker picker;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocBuilder<DocumentScanCubit, DocumentScanState>(
      builder: (context, s) {
        final cubit = context.read<DocumentScanCubit>();
        final sending = s.status == DocScanStatus.sending;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (s.status == DocScanStatus.done && s.result != null) ...[
                  _ResultView(result: s.result!, agentReview: cubit.agentReview),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const Key('doc_another'),
                    onPressed: cubit.reset,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: Text(l10n.docScanAnother),
                  ),
                ] else ...[
                  Text(l10n.docScanIntro, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  Text(l10n.docScanType, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final t in [kDocTypeAuto, ...kDocTypes])
                      ChoiceChip(
                        key: Key('doc_type_$t'),
                        label: Text(docTypeLabel(l10n, t)),
                        selected: s.docType == t,
                        onSelected: sending ? null : (_) => cubit.selectType(t),
                      ),
                  ]),
                  const SizedBox(height: 20),
                  if (s.error != null) ...[
                    _Banner(key: const Key('doc_error'), text: docScanErrorText(l10n, s.error!), error: true),
                    const SizedBox(height: 12),
                  ],
                  if (s.file != null) ...[
                    _Preview(file: s.file!),
                    const SizedBox(height: 12),
                  ],
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    if (picker.canUseCamera)
                      FilledButton.tonalIcon(
                        key: const Key('doc_camera'),
                        onPressed: sending ? null : () => _pick(context, picker.takePhoto),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(l10n.docScanTakePhoto),
                      ),
                    FilledButton.tonalIcon(
                      key: const Key('doc_file'),
                      onPressed: sending ? null : () => _pick(context, picker.pickFile),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(l10n.docScanChooseFile),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(l10n.docScanFormats, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('doc_send'),
                    onPressed: s.file != null && !sending
                        ? () => cubit.submit(context.read<LanguageCubit>().state.languageCode)
                        : null,
                    icon: sending
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.document_scanner_outlined),
                    label: Text(sending ? l10n.docScanReading : l10n.docScanSend),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pick(BuildContext context, Future<FileUpload?> Function() get) async {
    final cubit = context.read<DocumentScanCubit>();
    final FileUpload? file;
    try {
      file = await get();
    } catch (_) {
      // Camera refused / dialog failed: nothing picked.
      return;
    }
    if (file != null) cubit.filePicked(file);
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.file});

  final FileUpload file;

  @override
  Widget build(BuildContext context) {
    final kb = (file.bytes.length / 1024).ceil();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: Image.memory(
            file.bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox(height: 80, child: Icon(Icons.image_outlined, size: 48)),
          ),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.image_outlined),
          title: Text(file.filename, overflow: TextOverflow.ellipsis),
          subtitle: Text('$kb KB · ${file.mime}'),
        ),
      ]),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.agentReview});

  final ExtractResult result;
  final bool agentReview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      key: const Key('doc_result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.docScanResultTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.description_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.docScanDetected(docTypeLabel(l10n, result.docType)),
              style: theme.textTheme.titleMedium,
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.timer_outlined, size: 18),
          const SizedBox(width: 8),
          Text(l10n.docScanTime(docSeconds(result.processingMs)), style: theme.textTheme.bodySmall),
        ]),
        const SizedBox(height: 12),
        if (result.needsReview) ...[
          _Banner(
            key: const Key('doc_review'),
            text: agentReview ? l10n.docScanAgentReview : l10n.docScanNeedsReview,
            error: false,
          ),
          const SizedBox(height: 12),
        ],
        Card(
          child: result.fields.isEmpty
              ? Padding(padding: const EdgeInsets.all(16), child: Text(l10n.docScanNoFields))
              : Column(children: [
                  for (final (i, f) in result.fields.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      key: Key('doc_field_${f.name}'),
                      title: Text(docFieldLabel(l10n, f.name), style: theme.textTheme.labelLarge),
                      subtitle: SelectableText(docFieldValue(l10n, f.name, f.value), style: theme.textTheme.bodyLarge),
                      trailing: f.needsReview ? _ToCheckBadge(label: l10n.docScanToCheck) : null,
                    ),
                  ],
                ]),
        ),
      ],
    );
  }
}

class _ToCheckBadge extends StatelessWidget {
  const _ToCheckBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFFB45309); // amber 700: readable on light and dark cards
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.flag_outlined, size: 14, color: c),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text, required this.error});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = error ? scheme.errorContainer : scheme.secondaryContainer;
    final fg = error ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(error ? Icons.error_outline : Icons.support_agent, color: fg),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: fg))),
      ]),
    );
  }
}
