import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/locale/language_cubit.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../bloc/complaint_cubit.dart';
import '../widgets/complaint_labels.dart';

class ComplaintPage extends StatelessWidget {
  const ComplaintPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ComplaintCubit(sl(), sl()),
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.complaintTitle), actions: const [LanguageMenu()]),
        body: const ComplaintView(),
      ),
    );
  }
}

class ComplaintView extends StatefulWidget {
  const ComplaintView({super.key});

  @override
  State<ComplaintView> createState() => _ComplaintViewState();
}

class _ComplaintViewState extends State<ComplaintView> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final cubit = context.read<ComplaintCubit>();
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = file.name.isEmpty ? 'photo.jpg' : file.name;
    final lower = name.toLowerCase();
    final mime =
        file.mimeType ??
        (lower.endsWith('.png')
            ? 'image/png'
            : lower.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg');
    cubit.setPhoto(FileUpload(bytes: bytes, filename: name, mime: mime));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ComplaintCubit>().submit(
      description: _description.text,
      phone: _phone.text.trim(),
      lang: context.read<LanguageCubit>().state.languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocConsumer<ComplaintCubit, ComplaintState>(
      listenWhen: (a, b) => a.status != b.status && b.status == ComplaintStatus.editing,
      listener: (_, _) {
        _description.clear();
        _phone.clear();
      },
      builder: (context, state) {
        final cubit = context.read<ComplaintCubit>();
        if (state.status == ComplaintStatus.success) return _Created(ticket: state.ticket!);
        final busy = state.status == ComplaintStatus.submitting;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: state.category,
                    decoration: InputDecoration(labelText: l10n.complaintCategory),
                    items: [
                      for (final c in kTicketCategories)
                        DropdownMenuItem(value: c, child: Text(complaintCategoryLabel(l10n, c))),
                    ],
                    onChanged: busy ? null : (c) => cubit.selectCategory(c!),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.complaintUrgency, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final u in kUrgencies)
                        ChoiceChip(
                          label: Text(complaintUrgencyLabel(l10n, u)),
                          selected: state.urgency == u,
                          onSelected: busy ? null : (_) => cubit.selectUrgency(u),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('complaint_description'),
                    controller: _description,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: 4000,
                    decoration: InputDecoration(labelText: l10n.complaintDescription, alignLabelWithHint: true),
                    validator: (v) => (v ?? '').trim().length < 3 ? l10n.complaintDescriptionError : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('complaint_phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.complaintPhone,
                      hintText: '+257XXXXXXXX',
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      return t.isEmpty || ComplaintCubit.phonePattern.hasMatch(t) ? null : l10n.complaintPhoneError;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (state.photo == null)
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => _pickPhoto(ImageSource.gallery),
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(l10n.complaintAddPhoto),
                        ),
                        IconButton.outlined(
                          tooltip: l10n.complaintAddPhoto,
                          onPressed: busy ? null : () => _pickPhoto(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                        ),
                      ],
                    )
                  else
                    Card(
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(state.photo!.bytes, width: 56, height: 56, fit: BoxFit.cover),
                        ),
                        title: Text(state.photo!.filename, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          tooltip: l10n.complaintRemovePhoto,
                          onPressed: busy ? null : () => cubit.setPhoto(null),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ),
                  if (state.status == ComplaintStatus.failure) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.failure == ComplaintFailure.upload ? l10n.complaintErrUpload : l10n.complaintErrGeneric,
                      key: const Key('complaint_error'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('complaint_submit'),
                    onPressed: busy ? null : _submit,
                    icon: busy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_outlined),
                    label: Text(l10n.complaintSubmit),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Created extends StatelessWidget {
  const _Created({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: [
            Icon(Icons.check_circle, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(l10n.complaintCreatedTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(l10n.complaintTicketNumber, textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
            SelectableText(
              ticket.number,
              key: const Key('complaint_ticket_number'),
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                Chip(label: Text(complaintCategoryLabel(l10n, ticket.category))),
                Chip(label: Text(complaintUrgencyLabel(l10n, ticket.urgency))),
              ],
            ),
            const SizedBox(height: 12),
            Text(ticket.summary, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: context.read<ComplaintCubit>().reset, child: Text(l10n.complaintNew)),
          ],
        ),
      ),
    );
  }
}
