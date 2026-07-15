import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/session/session_providers.dart';
import '../data/api_connection_repository.dart';
import '../models/connection_view_state.dart';

final NotifierProvider<ConnectionViewModel, ConnectionViewState>
connectionViewModelProvider =
    NotifierProvider<ConnectionViewModel, ConnectionViewState>(
      ConnectionViewModel.new,
    );

class ConnectionViewModel extends Notifier<ConnectionViewState> {
  @override
  ConnectionViewState build() => const ConnectionViewState();

  Future<void> loadSavedAddress() async {
    final address = await ref
        .read(connectionRepositoryProvider)
        .loadSavedAddress();
    if (address != null) state = state.copyWith(suggestedAddress: address);
  }

  Future<bool> connect(String input) async {
    if (state.isConnecting) return false;
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      clearError: true,
    );
    try {
      final result = await ref
          .read(connectionRepositoryProvider)
          .connect(input);
      state = state.copyWith(
        status: ConnectionStatus.connected,
        connectedBase: result.serverBase,
        serverName: result.serverInfo.name,
        clearError: true,
      );
      // 连到（可能不同的）服务器是全新会话起点：复位上一会话的 401 失效标志。
      ref.read(sessionControllerProvider).markValid();
      return true;
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        status: ConnectionStatus.idle,
        errorMessage: failure.message,
      );
    } on Exception catch (error) {
      state = state.copyWith(
        status: ConnectionStatus.idle,
        errorMessage: error.toString(),
      );
    }
    return false;
  }
}
