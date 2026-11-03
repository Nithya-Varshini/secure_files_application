import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/formatters.dart';

class BackupState extends Equatable {
  const BackupState({
    this.lastBackupAt,
    this.lastFileName,
    this.running = false,
    this.progress = 0,
    this.step = '',
  });

  final DateTime? lastBackupAt;
  final String? lastFileName;
  final bool running;
  final double progress;
  final String step;

  bool isRecent(DateTime now) =>
      lastBackupAt != null && now.difference(lastBackupAt!).inDays < 30;

  @override
  List<Object?> get props => [
    lastBackupAt,
    lastFileName,
    running,
    progress,
    step,
  ];
}

/// PREVIEW: simulates the backup pipeline so the progress UI can be built.
class BackupCubit extends Cubit<BackupState> {
  BackupCubit() : super(const BackupState());

  Future<void> runBackup({required int itemCount}) async {
    if (state.running) return;
    final steps = [
      'Preparing $itemCount items',
      'Encrypting with your recovery key',
      'Writing backup file',
      'Verifying the backup opens',
    ];
    for (var s = 0; s < steps.length; s++) {
      for (var tick = 0; tick < 10; tick++) {
        if (isClosed) return;
        emit(
          BackupState(
            lastBackupAt: state.lastBackupAt,
            lastFileName: state.lastFileName,
            running: true,
            progress: (s * 10 + tick) / (steps.length * 10),
            step: steps[s],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    }
    final now = DateTime.now();
    if (!isClosed) {
      emit(
        BackupState(
          lastBackupAt: now,
          lastFileName:
              'vault-backup-${formatDate(now).replaceAll(' ', '-')}.vbak',
        ),
      );
    }
  }
}
