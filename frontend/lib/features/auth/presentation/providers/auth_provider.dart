import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_service.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  onboardingRequired,
}

class AuthState {
  final AuthStatus status;
  final String? activeCodSocio;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.activeCodSocio,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? activeCodSocio,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      activeCodSocio: activeCodSocio ?? this.activeCodSocio,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return AuthNotifier(storageService);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final StorageService _storageService;

  AuthNotifier(this._storageService) : super(const AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    final token = await _storageService.getAccessToken();
    final codSocio = await _storageService.getActiveCodSocio();

    if (token != null && token.isNotEmpty) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        activeCodSocio: codSocio,
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
      );
    }
  }

  Future<void> logout() async {
    await _storageService.clearAuthData();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void setOnboardingRequired() {
    state = state.copyWith(status: AuthStatus.onboardingRequired);
  }
}
