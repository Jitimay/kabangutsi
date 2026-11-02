import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/language_menu.dart';
import '../widgets/model_picker_view.dart';
import 'model_picker_session.dart';

/// `/chat/models`: the same session choice as the picker opened from the chat.
class ModelPickerPage extends StatelessWidget {
  const ModelPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = ModelPickerSession.cubit;
    final l10n = context.l10n;
    return BlocProvider.value(
      value: cubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.modelPickerTitle),
          actions: [
            IconButton(
              tooltip: l10n.modelPickerRefresh,
              icon: const Icon(Icons.refresh),
              onPressed: () => cubit.load(refresh: true),
            ),
            const LanguageMenu(),
          ],
        ),
        body: const ModelPickerView(),
      ),
    );
  }
}
