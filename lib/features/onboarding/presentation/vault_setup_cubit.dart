import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../authentication/domain/recovery_phrase.dart';

class VaultSetupState extends Equatable {
  const VaultSetupState({
    required this.phrase,
    this.pin,
    this.biometric = false,
  });

  final List<String> phrase;
  final String? pin;
  final bool biometric;

  VaultSetupState copyWith({String? pin, bool? biometric}) => VaultSetupState(
    phrase: phrase,
    pin: pin ?? this.pin,
    biometric: biometric ?? this.biometric,
  );

  @override
  List<Object?> get props => [phrase, pin, biometric];
}

/// Holds the choices made across the setup steps until the vault is created.
class VaultSetupCubit extends Cubit<VaultSetupState> {
  VaultSetupCubit() : super(VaultSetupState(phrase: RecoveryPhrase.generate()));

  void setPin(String pin) => emit(state.copyWith(pin: pin));

  void setBiometric(bool enabled) => emit(state.copyWith(biometric: enabled));
}
