import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/playback/playback_mode_controller.dart';
import 'package:hmusic/core/playback/playback_mode_store.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/security/token_store.dart';
import 'package:hmusic/core/session/session_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

class _TokenStore implements TokenStore {
  String? value = 'fixture-old';
  int clears = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async => value = token;
  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }
}

class _GatedAdapter implements HttpClientAdapter {
  final entered = Completer<void>();
  final response = Completer<ResponseBody>();
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (!entered.isCompleted) entered.complete();
    return response.future;
  }

  void reply(int status) => response.complete(
    ResponseBody.fromString(
      jsonEncode(
        status == 200
            ? {'items': <Object?>[]}
            : {
                'error': {
                  'code': status == 403
                      ? 'APP_VERSION_TOO_OLD'
                      : 'UNAUTHORIZED',
                  'message': 'fixture',
                  'details': {'minAppVersion': '99.0.0'},
                },
              },
      ),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    ),
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  late ProviderContainer container;
  late MemoryKeyValueStore preferences;
  late _GatedAdapter adapter;
  late _TokenStore tokens;
  setUp(() async {
    preferences = MemoryKeyValueStore();
    await preferences.setString('hmusic.serverBase', 'https://server.example');
    tokens = _TokenStore();
    adapter = _GatedAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(preferences),
        tokenStoreProvider.overrideWithValue(tokens),
        dioProvider.overrideWithValue(dio),
      ],
    );
    addTearDown(() {
      container.dispose();
      dio.close(force: true);
    });
  });

  test(
    'direct cold start restores mode before any Server request is sent',
    () async {
      await PlaybackModeStore(
        preferences: preferences,
      ).write(PlaybackMode.direct);
      await expectLater(
        container.read(apiClientProvider).getMap('/queue'),
        throwsA(
          isA<ApiFailure>().having(
            (f) => f.code,
            'code',
            'SERVER_MODE_INACTIVE',
          ),
        ),
      );
      expect(adapter.calls, 0);
      expect(tokens.value, 'fixture-old');
    },
  );

  for (final status in [200, 401, 403]) {
    test(
      'late $status response cannot write into a new playback mode',
      () async {
        var rejectedVersions = 0;
        final client = container.read(apiClientProvider);
        client.registerVersionRejectedHandler((_) => rejectedVersions++);
        final request = client.getMap('/queue');
        final check = expectLater(
          request,
          throwsA(
            isA<ApiFailure>().having(
              (failure) => failure.code,
              'code',
              'PLAYBACK_BACKEND_CHANGED',
            ),
          ),
        );
        await adapter.entered.future;
        await container
            .read(playbackModeProvider.notifier)
            .select(PlaybackMode.direct);
        adapter.reply(status);
        await check;
        expect(tokens.value, 'fixture-old');
        expect(tokens.clears, 0);
        expect(container.read(sessionControllerProvider).isInvalid, isFalse);
        expect(rejectedVersions, 0);
      },
    );
  }

  test('a stale 401 cannot clear a token from a newer login', () async {
    final request = container.read(apiClientProvider).getMap('/queue');
    final check = expectLater(request, throwsA(isA<ApiFailure>()));
    await adapter.entered.future;
    await tokens.write('fixture-new');
    adapter.reply(401);
    await check;
    expect(tokens.value, 'fixture-new');
    expect(tokens.clears, 0);
    expect(container.read(sessionControllerProvider).isInvalid, isFalse);
  });

  test(
    'several round trips invalidate the original response even after returning to Server',
    () async {
      final request = container.read(apiClientProvider).getMap('/queue');
      final check = expectLater(request, throwsA(isA<ApiFailure>()));
      await adapter.entered.future;
      final mode = container.read(playbackModeProvider.notifier);
      for (var i = 0; i < 3; i++) {
        await mode.select(PlaybackMode.direct);
        expect(await mode.restore(), PlaybackMode.direct);
        await mode.select(PlaybackMode.server);
        expect(await mode.restore(), PlaybackMode.server);
      }
      adapter.reply(401);
      await check;
      expect(tokens.clears, 0);
    },
  );
}
