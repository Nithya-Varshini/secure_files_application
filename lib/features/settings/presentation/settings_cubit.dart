import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auto_lock.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.autoLock = AutoLockDelay.immediately,
    this.biometricEnabled = false,
    this.screenshotProtection = true,
  });

  final ThemeMode themeMode;
  final AutoLockDelay autoLock;
  final bool biometricEnabled;
  final bool screenshotProtection;

  SettingsState copyWith({
    ThemeMode? themeMode,
    AutoLockDelay? autoLock,
    bool? biometricEnabled,
    bool? screenshotProtection,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      autoLock: autoLock ?? this.autoLock,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      screenshotProtection: screenshotProtection ?? this.screenshotProtection,
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    autoLock,
    biometricEnabled,
    screenshotProtection,
  ];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  void setThemeMode(ThemeMode mode) => emit(state.copyWith(themeMode: mode));

  void setAutoLock(AutoLockDelay delay) =>
      emit(state.copyWith(autoLock: delay));

  void setBiometric(bool enabled) =>
      emit(state.copyWith(biometricEnabled: enabled));

  void setScreenshotProtection(bool enabled) =>
      emit(state.copyWith(screenshotProtection: enabled));

  void reset() => emit(const SettingsState());
}
