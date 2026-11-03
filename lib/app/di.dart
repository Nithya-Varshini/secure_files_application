import 'package:get_it/get_it.dart';

import '../features/authentication/data/in_memory_auth_repository.dart';
import '../features/authentication/domain/auth_repository.dart';
import '../features/authentication/presentation/session_cubit.dart';
import '../features/files/data/fake_files_repository.dart';
import '../features/files/domain/files_repository.dart';
import '../features/media_vault/data/fake_media_repository.dart';
import '../features/media_vault/domain/media_repository.dart';
import '../features/notes/data/fake_notes_repository.dart';
import '../features/notes/domain/notes_repository.dart';
import '../features/settings/presentation/settings_cubit.dart';

final getIt = GetIt.instance;

/// Composition root: the only place that knows which implementation backs
/// each interface. Swapping a fake for the real encrypted store is a
/// one-line change here.
void configureDependencies() {
  getIt
    ..registerLazySingleton<AuthRepository>(InMemoryAuthRepository.new)
    ..registerLazySingleton<MediaRepository>(FakeMediaRepository.new)
    ..registerLazySingleton<FilesRepository>(FakeFilesRepository.new)
    ..registerLazySingleton<NotesRepository>(FakeNotesRepository.new)
    ..registerLazySingleton<SessionCubit>(() => SessionCubit(getIt()))
    ..registerLazySingleton<SettingsCubit>(SettingsCubit.new);
}
