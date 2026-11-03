import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:secure_files_application/app/app.dart';
import 'package:secure_files_application/app/di.dart';
import 'package:secure_files_application/core/crypto/vault_crypto.dart';
import 'package:secure_files_application/core/storage/vault_paths.dart';
import 'package:secure_files_application/features/onboarding/presentation/recovery_phrase_page.dart';
import 'package:secure_files_application/features/onboarding/presentation/vault_setup_cubit.dart';

import '../test/support/fakes.dart';

/// End-to-end walk through the whole app, as a user would tap it.
///
/// Run on a desktop window sized like a phone:
/// `flutter test integration_test -d windows --dart-define=SHOT_DIR=path`
/// With SHOT_DIR set, a PNG is saved at every step.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final captureButton = find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == 'Capture page',
  );
  const shotDir = String.fromEnvironment('SHOT_DIR');
  var shotIndex = 0;

  Future<void> shot(WidgetTester tester, String name) async {
    if (shotDir.isEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    // The root layer is in physical pixels; scale down to 1.5x logical.
    final dpr = tester.view.devicePixelRatio;
    final image = await layer.toImage(
      Offset.zero & (view.size * dpr),
      pixelRatio: 1.5 / dpr,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      '$shotDir/${(++shotIndex).toString().padLeft(2, '0')}_$name.png',
    );
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  }

  /// Waits for animations that end. Screens with endless animations
  /// (skeletons, the scanner line) use [settleFor] instead.
  Future<void> settle(WidgetTester tester) =>
      tester.pumpAndSettle(const Duration(milliseconds: 50));

  Future<void> settleFor(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Inactive tabs stay mounted (to keep their state), so labels such as
  /// "Files" exist twice; tap the bottom navigation bar explicitly.
  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 40));
    }
    await settleFor(tester, 600);
  }

  testWidgets('full user journey', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Real crypto and real files, in a throwaway folder. The Keystore and
    // fingerprint sensor are simulated (they exist only on Android), and
    // Argon2id uses test-strength parameters to keep the run fast.
    final biometrics = FakeBiometrics();
    final dir = await Directory.systemTemp.createTemp('vault_e2e');
    addTearDown(() => dir.delete(recursive: true));
    await getIt.reset();
    await configureDependencies(
      paths: VaultPaths(
        root: Directory('${dir.path}/vault'),
        temp: Directory('${dir.path}/tmp'),
      ),
      keystore: FakeKeystore(),
      biometrics: biometrics,
      mediaPicker: FakeMediaPicker(),
      documentPicker: FakeDocumentPicker(),
      scanCamera: FakeScanCamera(),
      kdf: KdfParams.testing,
    );
    await tester.pumpWidget(const VaultApp());
    await settle(tester);

    // --- Onboarding ---------------------------------------------------
    expect(find.text('Your private space'), findsOneWidget);
    await shot(tester, 'welcome');
    await tester.tap(find.text('Next'));
    await settle(tester);
    await shot(tester, 'welcome_2');
    await tester.tap(find.text('Skip'));
    await settle(tester);
    await tester.tap(find.text('Create my vault'));
    await settle(tester);

    // --- PIN: weak PIN rejected, then a good one confirmed -------------
    expect(find.text('Create a 6-digit PIN'), findsOneWidget);
    await enterPin(tester, '123456');
    expect(find.text('Avoid counting up or down.'), findsOneWidget);
    await shot(tester, 'pin_weak_rejected');
    await enterPin(tester, '482915');
    expect(find.text('Confirm your PIN'), findsOneWidget);
    await enterPin(tester, '482915');
    await settle(tester);

    // --- Recovery phrase ----------------------------------------------
    expect(find.text('Save your recovery phrase'), findsOneWidget);
    await shot(tester, 'phrase_blurred');
    final phrase = tester
        .element(find.byType(RecoveryPhrasePage))
        .read<VaultSetupCubit>()
        .state
        .phrase;
    await tester.tap(find.text('Tap to reveal'));
    await settle(tester);
    await shot(tester, 'phrase_revealed');
    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);

    // --- Verify 3 words ------------------------------------------------
    expect(find.text('Check your phrase'), findsOneWidget);
    final labels = tester
        .widgetList<Text>(find.textContaining('Word #'))
        .map((t) => int.parse(t.data!.substring(6)) - 1)
        .toList();
    for (var i = 0; i < labels.length; i++) {
      await tester.tap(
        find.descendant(
          of: find.byType(Wrap).at(i),
          matching: find.widgetWithText(ChoiceChip, phrase[labels[i]]),
        ),
      );
      await settle(tester);
    }
    await shot(tester, 'phrase_verified');
    await tester.tap(find.text('Continue'));
    await settle(tester);

    // --- Biometrics and ready -----------------------------------------
    await shot(tester, 'biometric_offer');
    await tester.tap(find.text('Use fingerprint'));
    await settle(tester);
    await shot(tester, 'vault_ready');
    await tester.tap(find.text('Open my vault'));
    await settleFor(tester, 1200);
    await settle(tester);

    // --- Home -----------------------------------------------------------
    expect(find.text('Your vault'), findsOneWidget);
    await shot(tester, 'home');

    // --- Gallery: import (encrypt), view, favourite, select -----------
    await openTab(tester, 'Gallery');
    await settle(tester);
    expect(find.text('No photos yet'), findsOneWidget);
    await shot(tester, 'gallery_empty');
    await tester.tap(find.text('Import'));
    await settleFor(tester, 1500);
    await settle(tester);
    expect(find.text('Originals are still in your gallery'), findsOneWidget);
    await shot(tester, 'originals_reminder');
    await tester.tap(find.text('Got it'));
    await settle(tester);
    await shot(tester, 'gallery');
    await tester.tap(find.byType(GridView).hitTestable().first);
    await settleFor(tester, 800);
    await settle(tester);
    await shot(tester, 'viewer');
    await tester.tap(find.text('Favourite'));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    await tester.longPress(find.byType(GridView).hitTestable().first);
    await settle(tester);
    await shot(tester, 'gallery_selecting');
    await tester.tap(find.byTooltip('Cancel selection'));
    await settle(tester);

    // --- Files: import (encrypt), preview the decrypted text ----------
    await openTab(tester, 'Files');
    await settle(tester);
    await tester.tap(find.text('Add'));
    await settle(tester);
    await tester.tap(find.text('Documents'));
    await settleFor(tester, 1200);
    await settle(tester);
    await shot(tester, 'files');
    await tester.tap(find.text('Wi-Fi codes.txt'));
    await settleFor(tester, 800);
    await settle(tester);
    expect(find.text('Router: 7741-ALPHA'), findsOneWidget);
    await shot(tester, 'file_preview');
    await tester.pageBack();
    await settle(tester);

    // --- Notes: create one through the editor -------------------------
    await openTab(tester, 'Notes');
    await settle(tester);
    await shot(tester, 'notes');
    await tester.tap(find.text('New note'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Test note');
    await tester.enterText(find.byType(TextField).last, 'Written by the test');
    await settleFor(tester, 900);
    await shot(tester, 'note_editor');
    await tester.pageBack();
    await settle(tester);
    expect(find.text('Test note'), findsOneWidget);
    await shot(tester, 'notes_after_save');

    // --- Scanner ----------------------------------------------------------
    await openTab(tester, 'Home');
    await settle(tester);
    await tester.tap(find.text('Scan'));
    await settleFor(tester, 800);
    await shot(tester, 'scanner');
    await tester.tap(captureButton);
    await settleFor(tester, 400);
    await tester.tap(captureButton);
    await settleFor(tester, 400);
    await tester.tap(find.text('Done'));
    await settleFor(tester, 800);
    await shot(tester, 'scan_review');
    await tester.tap(find.text('Save as encrypted PDF'));
    await settleFor(tester, 1500);
    await shot(tester, 'scan_saved_in_files');
    expect(find.textContaining('Scan '), findsWidgets);

    // --- Settings, security centre, backup ----------------------------
    await openTab(tester, 'Home');
    await settle(tester);
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    await shot(tester, 'settings');
    await tester.tap(find.text('Security centre'));
    await settle(tester);
    await shot(tester, 'security_centre');
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('Backup & restore'));
    await settle(tester);
    await tester.tap(find.text('Create encrypted backup'));
    await settleFor(tester, 1200);
    await shot(tester, 'backup_running');
    await settleFor(tester, 2500);
    await settle(tester);
    await shot(tester, 'backup_done');
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('Light'));
    await settle(tester);
    await shot(tester, 'settings_light');
    await tester.pageBack();
    await settle(tester);
    await shot(tester, 'home_light');

    // --- Lock, fingerprint unlock -------------------------------------
    await tester.tap(find.byTooltip('Lock vault'));
    await settleFor(tester, 1500);
    await settle(tester);
    // The lock screen offers the fingerprint at once; it succeeds.
    expect(find.text('Your vault'), findsOneWidget);
    await shot(tester, 'fingerprint_unlocked');

    // --- Lock, cancelled fingerprint, wrong PIN, right PIN -------------
    biometrics.accept = false;
    await tester.tap(find.byTooltip('Lock vault'));
    await settleFor(tester, 800);
    await settle(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    // Nothing about vault activity may remain visible once locked.
    expect(find.byType(SnackBar), findsNothing);
    await shot(tester, 'locked');
    await enterPin(tester, '111222');
    await settle(tester);
    expect(find.textContaining('Wrong PIN'), findsOneWidget);
    await shot(tester, 'wrong_pin');
    await enterPin(tester, '482915');
    await settleFor(tester, 1200);
    await settle(tester);
    expect(find.text('Your vault'), findsOneWidget);
    await shot(tester, 'unlocked_again');
  });
}
