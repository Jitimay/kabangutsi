import 'package:get_it/get_it.dart';

import '../env/env.dart';
import '../locale/language_cubit.dart';

final sl = GetIt.instance;

/// Registers app-wide dependencies. API clients and repositories (real + mock,
/// switched by [Env.useMock]) are added after G0 from `contracts/`.
Future<void> configureDependencies({Env? env}) async {
  await sl.reset();
  sl
    ..registerSingleton<Env>(env ?? Env.fromDefines())
    ..registerLazySingleton<LanguageCubit>(LanguageCubit.new);
}
