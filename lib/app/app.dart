import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/platform/secure_window.dart';
import '../core/security/auto_lock_guard.dart';
import '../core/storage/vault_paths.dart';
import '../core/theme/app_theme.dart';
import '../features/authentication/presentation/session_cubit.dart';
import '../features/backup_restore/presentation/backup_cubit.dart';
import '../features/files/presentation/files_cubit.dart';
import '../features/media_vault/presentation/media_cubit.dart';
import '../features/notes/presentation/notes_cubit.dart';
import '../features/settings/presentation/settings_cubit.dart';
import 'di.dart';
import 'router.dart';
import 'splash.dart';

class VaultApp extends StatefulWidget {
  const VaultApp({super.key});

  @override
  State<VaultApp> createState() => _VaultAppState();
}

class _VaultAppState extends State<VaultApp> {
  final _session = getIt<SessionCubit>();
  final _settings = getIt<SettingsCubit>();
  late final GoRouter _router = createRouter(_session);
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final AppLifecycleListener _lifecycle;
  DateTime? _hiddenAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    SecureWindow.setSecure(_settings.state.screenshotProtection);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  // Auto-lock: leaving the app starts the clock; coming back after the
  // chosen delay requires the PIN again.
  void _onHide() {
    // A system picker or the camera is open on our behalf.
    if (AutoLockGuard.suspended) return;
    _hiddenAt = DateTime.now();
    if (_settings.state.autoLock.duration == Duration.zero) _session.lock();
  }

  void _onShow() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null || AutoLockGuard.suspended) return;
    final away = DateTime.now().difference(hiddenAt);
    if (away >= _settings.state.autoLock.duration) _session.lock();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _session),
        BlocProvider.value(value: _settings),
        BlocProvider(create: (_) => MediaCubit(getIt(), getIt())),
        BlocProvider(create: (_) => FilesCubit(getIt(), getIt())),
        BlocProvider(create: (_) => NotesCubit(getIt())),
        BlocProvider(create: (_) => BackupCubit(getIt(), getIt(), _settings)),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<SessionCubit, SessionState>(
            listenWhen: (a, b) => a.status != b.status,
            listener: _onSessionChanged,
          ),
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (a, b) =>
                a.screenshotProtection != b.screenshotProtection,
            listener: (_, s) => SecureWindow.setSecure(s.screenshotProtection),
          ),
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
          buildWhen: (a, b) => a.themeMode != b.themeMode,
          builder: (context, settings) => MaterialApp.router(
            title: 'Kwam',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            scaffoldMessengerKey: _messenger,
            routerConfig: _router,
            builder: (context, child) =>
                SplashOverlay(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }

  /// Decrypted data exists in memory only while the vault is unlocked
  /// (threat model L14): load on unlock, wipe on lock.
  void _onSessionChanged(BuildContext context, SessionState state) {
    final media = context.read<MediaCubit>();
    final files = context.read<FilesCubit>();
    final notes = context.read<NotesCubit>();
    if (state.status == VaultStatus.unlocked) {
      media.load();
      files.load();
      notes.load();
    } else {
      // Messages like "Backup saved" must not linger on the lock screen.
      _messenger.currentState?.clearSnackBars();
      media.clear();
      files.clear();
      notes.clear();
      // Decrypted temp files (e.g. a video being played) go too.
      getIt<VaultPaths>().wipeTemp();
    }
  }
}
