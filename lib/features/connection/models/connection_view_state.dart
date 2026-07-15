enum ConnectionStatus { idle, connecting, connected }

class ConnectionViewState {
  const ConnectionViewState({
    this.status = ConnectionStatus.idle,
    this.suggestedAddress = '',
    this.connectedBase,
    this.serverName,
    this.errorMessage,
  });

  final ConnectionStatus status;
  final String suggestedAddress;
  final Uri? connectedBase;
  final String? serverName;
  final String? errorMessage;

  bool get isConnecting => status == ConnectionStatus.connecting;

  ConnectionViewState copyWith({
    ConnectionStatus? status,
    String? suggestedAddress,
    Uri? connectedBase,
    String? serverName,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ConnectionViewState(
      status: status ?? this.status,
      suggestedAddress: suggestedAddress ?? this.suggestedAddress,
      connectedBase: connectedBase ?? this.connectedBase,
      serverName: serverName ?? this.serverName,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
