import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/config/server_address_exception.dart';
import 'package:hmusic/core/config/server_address_policy.dart';

void main() {
  group('ServerAddressPolicy', () {
    test('adds HTTP scheme and removes trailing slash', () {
      final uri = ServerAddressPolicy.normalize('192.168.1.10:8090/');

      expect(uri.toString(), 'http://192.168.1.10:8090');
    });

    test('allows local HTTP in store edition', () {
      final uri = ServerAddressPolicy.normalize(
        'http://192.168.1.10:8090',
        storeEdition: true,
      );

      expect(uri.scheme, 'http');
    });

    test('requires HTTPS for public host in store edition', () {
      expect(
        () => ServerAddressPolicy.normalize(
          'http://music.example.com',
          storeEdition: true,
        ),
        throwsA(isA<ServerAddressException>()),
      );
    });

    test('allows public HTTPS in store edition', () {
      final uri = ServerAddressPolicy.normalize(
        'https://music.example.com',
        storeEdition: true,
      );

      expect(uri.toString(), 'https://music.example.com');
    });

    test('rejects credentials query fragment and subpath', () {
      const invalid = <String>[
        'http://user:pass@192.168.1.10',
        'http://192.168.1.10?token=x',
        'http://192.168.1.10#fragment',
        'http://192.168.1.10/hmusic',
      ];

      for (final value in invalid) {
        expect(
          () => ServerAddressPolicy.normalize(value),
          throwsA(isA<ServerAddressException>()),
          reason: value,
        );
      }
    });
  });
}
