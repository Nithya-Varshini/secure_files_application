import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/stream_listenable.dart';
import '../features/authentication/presentation/change_pin_page.dart';
import '../features/authentication/presentation/lock_page.dart';
import '../features/authentication/presentation/recover_page.dart';
import '../features/authentication/presentation/session_cubit.dart';
import '../features/backup_restore/presentation/backup_page.dart';
import '../features/backup_restore/presentation/restore_page.dart';
import '../features/files/presentation/file_preview_page.dart';
import '../features/files/presentation/files_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/media_vault/presentation/gallery_page.dart';
import '../features/notes/presentation/note_editor_page.dart';
import '../features/notes/presentation/notes_page.dart';
import '../features/onboarding/presentation/biometric_setup_page.dart';
import '../features/onboarding/presentation/recovery_phrase_page.dart';
import '../features/onboarding/presentation/setup_pin_page.dart';
import '../features/onboarding/presentation/vault_setup_cubit.dart';
import '../features/onboarding/presentation/verify_phrase_page.dart';
import '../features/onboarding/presentation/welcome_page.dart';
import '../features/scanner/presentation/scanner_page.dart';
import '../features/security_center/presentation/security_center_page.dart';
import '../features/settings/presentation/settings_page.dart';
import 'home_shell.dart';
import 'routes.dart';

GoRouter createRouter(SessionCubit session) {
  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: StreamListenable(session.stream),
    redirect: (context, state) => guard(session.state.status, state.uri),
    routes: [
      GoRoute(
        path: Routes.welcome,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const WelcomePage()),
      ),
      // The setup steps share one VaultSetupCubit that lives as long as
      // any step is on screen.
      ShellRoute(
        builder: (context, state, child) =>
            BlocProvider(create: (_) => VaultSetupCubit(), child: child),
        routes: [
          GoRoute(
            path: Routes.setupPin,
            builder: (context, state) => const SetupPinPage(),
          ),
          GoRoute(
            path: Routes.setupRecovery,
            builder: (context, state) => const RecoveryPhrasePage(),
          ),
          GoRoute(
            path: Routes.setupVerify,
            builder: (context, state) => const VerifyPhrasePage(),
          ),
          GoRoute(
            path: Routes.setupBiometric,
            builder: (context, state) => const BiometricSetupPage(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.lock,
        // No transition, for two reasons:
        // * Security: vault content must vanish at once, not fade out.
        // * Correctness: during a fade the old tab shell stays mounted; a
        //   quick unlock (fingerprint) would build a second shell with the
        //   same GlobalKey before the first is gone ("Duplicate GlobalKey").
        pageBuilder: (context, state) =>
            NoTransitionPage(key: state.pageKey, child: const LockPage()),
      ),
      GoRoute(
        path: Routes.recover,
        builder: (context, state) => const RecoverPage(),
      ),
      GoRoute(
        path: Routes.restore,
        builder: (context, state) => const RestorePage(),
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => HomeShell(shell: shell),
        navigatorContainerBuilder: (context, shell, children) =>
            FadingBranchContainer(
              currentIndex: shell.currentIndex,
              children: children,
            ),
        branches: [
          _tab(Routes.home, const HomePage()),
          _tab(Routes.gallery, const GalleryPage()),
          _tab(Routes.files, const FilesPage()),
          _tab(Routes.notes, const NotesPage()),
        ],
      ),
      GoRoute(
        path: '/file/:id',
        builder: (context, state) =>
            FilePreviewPage(fileId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/note/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return NoteEditorPage(noteId: id == 'new' ? null : id);
        },
      ),
      GoRoute(
        path: Routes.scanner,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const ScannerPage()),
      ),
      GoRoute(
        path: Routes.backup,
        builder: (context, state) => const BackupPage(),
      ),
      GoRoute(
        path: Routes.security,
        builder: (context, state) => const SecurityCenterPage(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsPage(),
        routes: [
          GoRoute(
            path: 'change-pin',
            builder: (context, state) => const ChangePinPage(),
          ),
        ],
      ),
    ],
  );
}

/// Decides where the user may be for a given vault status.
///
/// * No vault: only onboarding is reachable.
/// * Locked: only the lock and recovery screens; the requested location is
///   remembered in `?from=` and restored after unlocking.
/// * Unlocked: onboarding and the lock screen bounce back into the vault.
@visibleForTesting
String? guard(VaultStatus status, Uri uri) {
  final path = uri.path;
  final onboarding =
      path == Routes.welcome ||
      path.startsWith('/setup') ||
      path == Routes.restore;
  final authScreen = path == Routes.lock || path == Routes.recover;

  switch (status) {
    case VaultStatus.noVault:
      return onboarding ? null : Routes.welcome;
    case VaultStatus.locked:
      if (authScreen) return null;
      final from = onboarding ? Routes.home : uri.toString();
      return Uri(path: Routes.lock, queryParameters: {'from': from}).toString();
    case VaultStatus.unlocked:
      if (onboarding || authScreen) {
        return uri.queryParameters['from'] ?? Routes.home;
      }
      return null;
  }
}

StatefulShellBranch _tab(String path, Widget page) => StatefulShellBranch(
  routes: [
    GoRoute(
      path: path,
      // A messenger per tab: a message is shown by that tab's own Scaffold,
      // which lifts its floating button above it. On the outer shell
      // Scaffold it would cover "New note" / "Import" / "Add" for seconds.
      // One shared messenger would draw it in all four (kept-alive) tabs,
      // which also breaks Hero (duplicate SnackBar hero tags).
      pageBuilder: (context, state) =>
          NoTransitionPage(child: ScaffoldMessenger(child: page)),
    ),
  ],
);

Page<void> _fadeThrough(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondary,
          child: child,
        ),
  );
}
