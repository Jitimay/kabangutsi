import 'package:get_it/get_it.dart';

import '../../data/api/api_client.dart';
import '../../data/api/ws_client.dart';
import '../../data/mock/mock_backend.dart';
import '../../data/repositories/api_repositories.dart';
import '../../data/repositories/repositories.dart';
import '../env/env.dart';
import '../locale/language_cubit.dart';
import '../session/agent_session_cubit.dart';

final sl = GetIt.instance;

/// Registers app-wide dependencies. Repositories are interfaces with a real
/// (REST/SSE/WebSocket) and a mock implementation, switched by `USE_MOCK`.
/// BLoCs/Cubits for a screen are created by that screen with `sl<Repo>()`.
Future<void> configureDependencies({Env? env}) async {
  await sl.reset();
  final e = env ?? Env.fromDefines();
  sl
    ..registerSingleton<Env>(e)
    ..registerLazySingleton<LanguageCubit>(LanguageCubit.new);

  if (Env.kUseMock && e.useMock) {
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
      ..registerLazySingleton<LoanRepository>(() => ApiLoanRepository(api))
      ..registerLazySingleton<TicketRepository>(() => ApiTicketRepository(api))
      ..registerLazySingleton<BranchRepository>(() => ApiBranchRepository(api))
      ..registerLazySingleton<UssdRepository>(() => ApiUssdRepository(api))
      ..registerLazySingleton<AgentRepository>(() => ApiAgentRepository(api, ws));
  }
  sl.registerLazySingleton<AgentSessionCubit>(() => AgentSessionCubit(sl<AgentRepository>()));
}
