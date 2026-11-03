import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../core/crypto/vault_crypto.dart';
import '../core/platform/biometric_auth.dart';
import '../core/platform/hardware_keystore.dart';
import '../core/security/vault_key.dart';
import '../core/storage/blob_store.dart';
import '../core/storage/encrypted_index.dart';
import '../core/storage/vault_paths.dart';
import '../features/authentication/data/local_auth_repository.dart';
import '../features/authentication/domain/auth_repository.dart';
import '../features/authentication/presentation/session_cubit.dart';
import '../features/files/data/fake_files_repository.dart';
import '../features/files/domain/files_repository.dart';
import '../features/media_vault/data/fake_media_repository.dart';
import '../features/media_vault/domain/media_repository.dart';
import '../features/notes/data/local_notes_repository.dart';
import '../features/notes/domain/notes_repository.dart';
import '../features/settings/presentation/settings_cubit.dart';

final getIt = GetIt.instance;

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Composition root: the only place that knows which implementation backs
/// each interface. Tests pass their own [paths], [keystore], [biometrics]
/// and cheap [kdf] parameters.
Future<void> configureDependencies({
  VaultPaths? paths,
  HardwareKeystore? keystore,
  BiometricAuth? biometrics,
  KdfParams kdf = KdfParams.recommended,
}) async {
  final vaultPaths = paths ?? await VaultPaths.resolve();
  // Leftover decrypted files from a crash or force-stop (threat model L7).
  await vaultPaths.wipeTemp();

  final key = VaultKey();
  final auth = LocalAuthRepository(
    paths: vaultPaths,
    key: key,
    keystore:
        keystore ??
        (_isAndroid
            ? AndroidHardwareKeystore()
            : const UnavailableHardwareKeystore()),
    biometrics:
        biometrics ??
        (_isAndroid ? LocalBiometricAuth() : const UnavailableBiometricAuth()),
    kdf: kdf,
  );
  await auth.init();
  final lockout = await auth.readLockout();
  final settings = await SettingsCubit.load(vaultPaths.settings);

  getIt
    ..registerSingleton<VaultPaths>(vaultPaths)
    ..registerSingleton<VaultKey>(key)
    ..registerSingleton<AuthRepository>(auth)
    ..registerLazySingleton(() => EncryptedIndex(getIt(), getIt()))
    ..registerLazySingleton(() => BlobStore(getIt(), getIt()))
    ..registerLazySingleton<MediaRepository>(FakeMediaRepository.new)
    ..registerLazySingleton<FilesRepository>(FakeFilesRepository.new)
    ..registerLazySingleton<NotesRepository>(
      () => LocalNotesRepository(getIt()),
    )
    ..registerSingleton(SessionCubit(auth, lockout: lockout))
    ..registerSingleton(
      SettingsCubit(file: vaultPaths.settings, initial: settings),
    );
}
