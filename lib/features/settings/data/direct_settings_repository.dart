import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/direct/direct_providers.dart';
import '../../../core/direct/mi_direct_account_repository.dart';
import '../../../core/direct/mi_direct_providers.dart';
import '../../../core/direct/music/direct_music_http.dart';
import '../../../core/direct/music/platform_track_mapper.dart';
import '../../../core/direct/storage/direct_local_store.dart';
import '../../../core/network/api_failure.dart';
import '../models/config_options.dart';
import '../models/direct_options.dart';
import '../models/server_config.dart';
import '../models/settings_summary.dart';
import 'settings_repository.dart';

final directSettingsRepositoryProvider = Provider<DirectSettingsRepository>(
  (ref) => DirectSettingsRepository(
    ref.watch(directLocalStoreProvider),
    account: ref.watch(miDirectAccountRepositoryProvider),
  ),
);

class DirectSettingsRepository implements SettingsRepository {
  const DirectSettingsRepository(
    this._store, {
    MiDirectAccountRepository? account,
  }) : _account = account;
  final DirectLocalStore _store;
  final MiDirectAccountRepository? _account;

  ServerConfig _config(Map<String, Object?> data) => ServerConfig(
    serverName: '本机直连',
    defaultQuality: '${data['defaultQuality'] ?? '320k'}',
    searchStrategy: '${data['searchStrategy'] ?? 'qqFirst'}',
    resolveStrategy: '${data['resolveStrategy'] ?? 'originalFirst'}',
    extraPlayMusicModels:
        (data['extraPlayMusicModels'] as List?)?.whereType<String>().toList() ??
        const [],
    manualTracks: musicRows(
      data['manualTracks'],
    ).map(ManualTrack.fromJson).toList(),
  );

  @override
  Future<ServerConfig> getConfig() async =>
      _config(await _store.read('config'));

  @override
  Future<ServerConfig> patchConfig({
    String? serverName,
    String? defaultQuality,
    String? searchStrategy,
    String? resolveStrategy,
    List<String>? extraPlayMusicModels,
    List<ManualTrack>? manualTracks,
    bool? announceTracks,
  }) => _store.update('config', (data) {
    _option(kQualityOptions, defaultQuality);
    _option(kSearchStrategyOptions, searchStrategy);
    _option(kResolveStrategyOptions, resolveStrategy);
    if (announceTracks == true) throw _serverOnly;
    for (final track in manualTracks ?? <ManualTrack>[]) {
      validateMusicUri(track.url);
      if (track.title.trim().isEmpty) throw _invalid;
    }
    data.addAll({
      if (defaultQuality != null) 'defaultQuality': defaultQuality,
      if (searchStrategy != null) 'searchStrategy': searchStrategy,
      if (resolveStrategy != null) 'resolveStrategy': resolveStrategy,
      if (extraPlayMusicModels != null)
        'extraPlayMusicModels': _models(extraPlayMusicModels),
      if (manualTracks != null)
        'manualTracks': manualTracks.map((t) => t.toJson()).toList(),
    });
    return _config(data);
  });

  Future<DirectOptions> getOptions() async {
    final data = await _store.read('config');
    return DirectOptions(
      config: _config(data),
      qqDirect: data['qqDirect'] == true,
      proxyHost: '${data['proxyHost'] ?? ''}',
    );
  }

  Future<void> saveOptions(DirectOptions options) async {
    final host = options.proxyHost.trim();
    final ip = InternetAddress.tryParse(host);
    if (host.isNotEmpty &&
        (ip == null ||
            ip.isLoopback ||
            ip.type != InternetAddressType.IPv4 ||
            ip.address == '0.0.0.0' ||
            ip.isMulticast)) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '代理地址需填写音箱可访问的本机局域网 IPv4 地址',
      );
    }
    final config = options.config;
    _option(kQualityOptions, config.defaultQuality);
    _option(kSearchStrategyOptions, config.searchStrategy);
    _option(kResolveStrategyOptions, config.resolveStrategy);
    await _store.update(
      'config',
      (data) => data.addAll({
        'defaultQuality': config.defaultQuality,
        'searchStrategy': config.searchStrategy,
        'resolveStrategy': config.resolveStrategy,
        'qqDirect': options.qqDirect,
        'proxyHost': host,
        'extraPlayMusicModels': _models(config.extraPlayMusicModels),
      }),
    );
  }

  @override
  Future<SettingsSummary> loadSummary() async {
    final snapshots = await Future.wait([
      _store.read('config'),
      _store.read('devices'),
      _store.read('sources'),
    ]);
    final config = _config(snapshots[0]);
    final devices = musicRows(snapshots[1]['items']);
    final selected = devices
        .where((device) => device['deviceID'] == snapshots[1]['selectedId'])
        .firstOrNull;
    final plugins = musicRows(snapshots[2]['plugins']);
    final enabled = plugins.where((plugin) => plugin['enabled'] == true).length;
    return SettingsSummary(
      mi: await _miSummary(),
      devices: selected?['name']?.toString() ?? '本机播放',
      sources: plugins.isEmpty
          ? '尚未添加音源'
          : '${plugins.length} 个音源 · $enabled 个启用',
      config:
          '${configOptionLabel(kQualityOptions, config.defaultQuality)} · ${configOptionLabel(kSearchStrategyOptions, config.searchStrategy)}',
      tracks: '${config.manualTracks.length} 首',
    );
  }

  Future<String> _miSummary() async {
    try {
      final id =
          _account?.cachedAccount?.userId ?? await _account?.storedUserId();
      if (id == null) return '未登录';
      return id.length < 5
          ? '已登录'
          : '已登录 ${id.substring(0, 2)}***${id.substring(id.length - 2)}';
    } on Exception {
      return '暂时无法读取账号';
    }
  }

  List<String> _models(List<String> values) {
    final models = values
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (models.any((model) => !RegExp(r'^[A-Z0-9_-]{1,32}$').hasMatch(model))) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '音箱型号请使用字母或数字，并用逗号分隔',
      );
    }
    return models;
  }

  void _option(List<(String, String)> options, String? value) {
    if (value != null && !options.any((option) => option.$1 == value)) {
      throw _invalid;
    }
  }

  static const _invalid = ApiFailure(
    kind: ApiFailureKind.invalidConfiguration,
    message: '直连配置无效',
  );
  static const _serverOnly = ApiFailure(
    kind: ApiFailureKind.invalidConfiguration,
    message: '此功能需要服务器模式',
  );
  @override
  Future<HMusicPlaybackState> getPlaybackState() async => throw _serverOnly;
  @override
  Future<void> playTestTone() async => throw _serverOnly;
  @override
  Future<void> speak(String text) async => throw _serverOnly;
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => throw _serverOnly;
  @override
  Future<void> deleteAccount({required String password}) async =>
      throw _serverOnly;
}
