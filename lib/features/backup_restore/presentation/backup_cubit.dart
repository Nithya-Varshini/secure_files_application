import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/platform/pickers.dart';
import '../../../core/utils/formatters.dart';
import '../../settings/presentation/settings_cubit.dart';
import '../data/backup_service.dart';

enum BackupOutcome { saved, cancelled, failed }

class BackupState extends Equatable {
  const BackupState({this.running = false, this.step = ''});

  final bool running;
  final String step;

  @override
  List<Object?> get props => [running, step];
}

class BackupCubit extends Cubit<BackupState> {
  BackupCubit(this._service, this._picker, this._settings)
    : super(const BackupState());

  final BackupService _service;
  final DocumentPicker _picker;
  final SettingsCubit _settings;

  Future<BackupOutcome> runBackup() async {
    if (state.running) return BackupOutcome.failed;
    emit(const BackupState(running: true, step: 'Encrypting your vault…'));
    try {
      final file = await _service.create();
      try {
        emit(const BackupState(running: true, step: 'Choose where to save…'));
        final now = DateTime.now();
        final saved = await _picker.saveCopy(
          name: 'vault-backup-${formatDate(now).replaceAll(' ', '-')}.vbak',
          bytes: await file.readAsBytes(),
          mimeType: 'application/octet-stream',
        );
        if (saved) _settings.recordBackup(now);
        return saved ? BackupOutcome.saved : BackupOutcome.cancelled;
      } finally {
        await file.delete();
      }
    } on Exception {
      return BackupOutcome.failed;
    } finally {
      if (!isClosed) emit(const BackupState());
    }
  }
}
