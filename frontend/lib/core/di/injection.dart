import 'package:get_it/get_it.dart';

import '../../data/api/api_client.dart';
import '../../data/api/ws_client.dart';
import '../../data/mock/mock_backend.dart';
import '../../data/repositories/api_repositories.dart';
import '../../data/repositories/repositories.dart';
import '../../features/document_scan/services/document_picker.dart';
import '../env/env.dart';
import '../locale/language_cubit.dart';
import '../session/agent_session_cubit.dart';

final sl = GetIt.instance;

/// Registers app-wide dependencies. Repositories are interfaces with a real
/// (REST/SSE/WebSocket) and a mock implementation, switched by `USE_MOCK`.
/// BLoCs/Cubits for a screen are created by that screen with `sl<Repo>()`.
///
/// Tests pass [registerRepositories] (e.g. `registerMockRepositories`) to use the
/// mock without a `--dart-define`; the app decides with the compile-time
/// [Env.kUseMock] so the mock is tree-shaken out of real builds.
Future<void> configureDependencies({Env? env, void Function(GetIt sl)? registerRepositories}) async {
  await sl.reset();
  final e = env ?? Env.fromDefines();
  sl
    ..registerSingleton<Env>(e)
    ..registerLazySingleton<LanguageCubit>(LanguageCubit.new);

  if (registerRepositories != null) {
    registerRepositories(sl);
  } else if (Env.kUseMock) {
    registerMockRepositories(sl);
  } else {
    final api = ApiClient(e);
    final ws = WsClient(e);
    sl
      ..registerSingleton<ApiClient>(api)
      ..registerLazySingleton<ModelRepository>(() => ApiModelRepository(api))
      ..registerLazySingleton<ConversationRepository>(() => ApiConversationRepository(api, ws))
      ..registerLazySingleton<FileRepository>(() => ApiFileRepository(api))
      ..registerLazySingleton<CardRepository>(() => ApiCardRepository(api))
      ..registerLazySingleton<DocumentRepository>(() => ApiDocumentRepository(api))
      ..registerLazySingleton<LoanRepository>(() => ApiLoanRepository(api))
      ..registerLazySingleton<TicketRepository>(() => ApiTicketRepository(api))
      ..registerLazySingleton<BranchRepository>(() => ApiBranchRepository(api))
      ..registerLazySingleton<UssdRepository>(() => ApiUssdRepository(api))
      ..registerLazySingleton<AgentRepository>(() => ApiAgentRepository(api, ws));
  }
  sl
    ..registerLazySingleton<AgentSessionCubit>(() => AgentSessionCubit(sl<AgentRepository>()))
    ..registerLazySingleton<DocumentPicker>(() => const PlatformDocumentPicker());
}
