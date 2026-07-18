import '../data/lan_server_scanner.dart';

enum ConnectionStatus { idle, connecting, connected }

class ConnectionViewState {
  const ConnectionViewState({
    this.status = ConnectionStatus.idle,
    this.suggestedAddress = '',
    this.connectedBase,
    this.serverName,
    this.errorMessage,
    this.discovering = false,
    this.discoverCompleted = false,
    this.discovered = const <DiscoveredServer>[],
  });

  final ConnectionStatus status;
  final String suggestedAddress;
  final Uri? connectedBase;
  final String? serverName;
  final String? errorMessage;

  // 局域网自动发现：开屏即扫，结果逐台追加（先发现先显示）。
  final bool discovering;

  // 是否完成过至少一轮扫描：区分「尚未扫过」与「扫完没找到」——手动表单
  // 只在后者自动展开，避免开屏首帧闪现又缩回。
  final bool discoverCompleted;
  final List<DiscoveredServer> discovered;

  bool get isConnecting => status == ConnectionStatus.connecting;

  ConnectionViewState copyWith({
    ConnectionStatus? status,
    String? suggestedAddress,
    Uri? connectedBase,
    String? serverName,
    String? errorMessage,
    bool clearError = false,
    bool? discovering,
    bool? discoverCompleted,
    List<DiscoveredServer>? discovered,
  }) {
    return ConnectionViewState(
      status: status ?? this.status,
      suggestedAddress: suggestedAddress ?? this.suggestedAddress,
      connectedBase: connectedBase ?? this.connectedBase,
      serverName: serverName ?? this.serverName,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      discovering: discovering ?? this.discovering,
      discoverCompleted: discoverCompleted ?? this.discoverCompleted,
      discovered: discovered ?? this.discovered,
    );
  }
}
