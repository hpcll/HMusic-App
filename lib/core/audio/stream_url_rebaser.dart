import '../config/server_config_store.dart';
import '../network/api_failure.dart';

class StreamUrlRebaser {
  const StreamUrlRebaser({required ServerConfigStore serverConfigStore})
    : _serverConfigStore = serverConfigStore;

  final ServerConfigStore _serverConfigStore;

  Future<Uri> rebase(String streamUrl) async {
    final serverBase = await _serverConfigStore.read();
    final source = Uri.tryParse(streamUrl);
    if (serverBase == null ||
        source == null ||
        (source.scheme != 'http' && source.scheme != 'https') ||
        !source.path.startsWith('/api/v1/proxy/')) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidResponse,
        message: '服务器返回了无效的音频地址',
      );
    }
    return serverBase.replace(
      path: source.path,
      query: source.hasQuery ? source.query : null,
    );
  }
}
