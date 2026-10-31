import '../../../core/di/injection.dart';
import '../../../data/repositories/repositories.dart';
import '../bloc/model_picker_cubit.dart';

/// The model choice lives for the whole app session and is shared by the chat
/// screen and the `/chat/models` route. Recreated if DI was reset.
abstract final class ModelPickerSession {
  static ModelPickerCubit? _cubit;

  static ModelPickerCubit get cubit {
    final repo = sl<ModelRepository>();
    final c = _cubit;
    if (c != null && !c.isClosed && identical(c.modelRepository, repo)) return c;
    return _cubit = ModelPickerCubit(repo, sl<ConversationRepository>())..load();
  }
}
