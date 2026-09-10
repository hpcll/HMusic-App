import 'server_config.dart';

class DirectOptions {
  const DirectOptions({
    required this.config,
    this.qqDirect = false,
    this.proxyHost = '',
  });
  final ServerConfig config;
  final bool qqDirect;
  final String proxyHost;
}

class DirectOptionsState {
  const DirectOptionsState({
    this.options,
    this.saving = false,
    this.message,
    this.failed = false,
  });
  final DirectOptions? options;
  final bool saving;
  final String? message;
  final bool failed;
}
