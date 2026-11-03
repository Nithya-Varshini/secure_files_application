import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/storage/vault_paths.dart';
import '../domain/auto_lock.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.autoLock = AutoLockDelay.immediately,
    this.screenshotProtection = true,
    this.lastBackupAt,
  });

  final ThemeMode themeMode;
  final AutoLockDelay autoLock;
  final bool screenshotProtection;
  final DateTime? lastBackupAt;

  SettingsState copyWith({
    ThemeMode? themeMode,
    AutoLockDelay? autoLock,
    bool? screenshotProtection,
    DateTime? lastBackupAt,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      autoLock: autoLock ?? this.autoLock,
      screenshotProtection: screenshotProtection ?? this.screenshotProtection,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    );
  }

  /// Settings are not secret, and the theme and lock delay are needed before
  /// the vault is unlocked, so they are stored unencrypted.
  Map<String, Object?> toJson() => {
    'theme': themeMode.name,
    'autoLock': autoLock.name,
    'screenshots': screenshotProtection,
    'lastBackup': lastBackupAt?.millisecondsSinceEpoch,
  };

  factory SettingsState.fromJson(Map<String, Object?> json) {
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return SettingsState(
      themeMode: byName(ThemeMode.values, json['theme'], ThemeMode.system),
      autoLock: byName(
        AutoLockDelay.values,
        json['autoLock'],
        AutoLockDelay.immediately,
      ),
      screenshotProtection: json['screenshots'] as bool? ?? true,
      lastBackupAt: json['lastBackup'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(json['lastBackup']! as int),
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    autoLock,
    screenshotProtection,
    lastBackupAt,
  ];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({this._file, SettingsState initial = const SettingsState()})
    : super(initial);

  final File? _file;

  static Future<SettingsState> load(File file) async {
    try {
      if (!await file.exists()) return const SettingsState();
      return SettingsState.fromJson(
        (jsonDecode(await file.readAsString()) as Map).cast<String, Object?>(),
      );
    } on FormatException {
      return const SettingsState();
    }
  }

  @override
  void emit(SettingsState state) {
    super.emit(state);
    final file = _file;
    if (file != null) {
      VaultPaths.writeAtomic(file, utf8.encode(jsonEncode(state.toJson())));
    }
  }

  void setThemeMode(ThemeMode mode) => emit(state.copyWith(themeMode: mode));

  void setAutoLock(AutoLockDelay delay) =>
      emit(state.copyWith(autoLock: delay));

  void setScreenshotProtection(bool enabled) =>
      emit(state.copyWith(screenshotProtection: enabled));

  void recordBackup(DateTime at) => emit(state.copyWith(lastBackupAt: at));

  void reset() => emit(const SettingsState());
}
