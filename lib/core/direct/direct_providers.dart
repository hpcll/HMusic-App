import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/client_playback_capabilities.dart';
import '../playback/playback_mode.dart';
import '../playback/playback_mode_controller.dart';
import '../providers/infrastructure_providers.dart';
import '../queue/direct_queue_repository.dart';
import 'direct_device_registry.dart';
import 'mi_direct_providers.dart';
import 'music/direct_audio_proxy.dart';
import 'music/direct_lx_sources.dart';
import 'music/direct_music_http.dart';
import 'music/direct_music_search.dart';
import 'music/direct_playlist_importer.dart';
import 'music/direct_track_resolver.dart';
import 'playback/direct_playback_repository.dart';
import 'storage/direct_local_store.dart';

final directLocalStoreProvider = Provider<DirectLocalStore>(
  (ref) => DirectLocalStore(ref.watch(keyValueStoreProvider)),
);
final directQueueRepositoryProvider = Provider<DirectQueueRepository>(
  (ref) => DirectQueueRepository(ref.watch(directLocalStoreProvider)),
);
final directMusicHttpProvider = Provider<DirectMusicHttp>((ref) {
  final http = DirectMusicHttp();
  ref.onDispose(http.close);
  return http;
});
final directMusicSearchProvider = Provider<DirectMusicSearch>(
  (ref) => DirectMusicSearch(ref.watch(directMusicHttpProvider)),
);
final directLxSourcesProvider = Provider<DirectLxSources>((ref) {
  final sources = DirectLxSources(
    ref.watch(directLocalStoreProvider),
    ref.watch(directMusicHttpProvider),
  );
  ref.onDispose(sources.close);
  return sources;
});
final directTrackResolverProvider = Provider<DirectTrackResolver>(
  (ref) => DirectTrackResolver(
    ref.watch(directLxSourcesProvider),
    ref.watch(directMusicSearchProvider),
    ref.watch(directLocalStoreProvider),
  ),
);
final directAudioProxyProvider = Provider<DirectAudioProxy>((ref) {
  final proxy = DirectAudioProxy();
  ref.onDispose(() => unawaited(proxy.dispose()));
  return proxy;
});
final directDeviceRegistryProvider = Provider<DirectDeviceRegistry>(
  (ref) => DirectDeviceRegistry(
    ref.watch(miDirectAccountRepositoryProvider),
    ref.watch(directLocalStoreProvider),
    ref.watch(clientPlaybackCapabilitiesProvider),
    localOnly: ref.watch(playbackModeProvider) == PlaybackMode.player,
  ),
);
final directPlaylistImporterProvider = Provider<DirectPlaylistImporter>(
  (ref) => DirectPlaylistImporter(ref.watch(directMusicHttpProvider)),
);
final directPlaybackRepositoryProvider = Provider<DirectPlaybackRepository>(
  (ref) => DirectPlaybackRepository(
    store: ref.watch(directLocalStoreProvider),
    queue: ref.watch(directQueueRepositoryProvider),
    devices: ref.watch(directDeviceRegistryProvider),
    resolver: ref.watch(directTrackResolverProvider),
    proxy: ref.watch(directAudioProxyProvider),
    client: ref.watch(miMinaClientProvider),
  ),
);
