import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/connection/data/api_connection_repository.dart';
import 'package:hmusic/features/connection/data/connection_repository.dart';
import 'package:hmusic/features/connection/models/connection_result.dart';
import 'package:hmusic/features/connection/views/connection_page.dart';

class _FakeConnectionRepository implements ConnectionRepository {
  @override
  Future<ConnectionResult> connect(String input) {
    throw UnimplementedError();
  }

  @override
  Future<String?> loadSavedAddress() async => 'http://192.168.1.10:8090';
}

void main() {
  testWidgets('shows server connection form and restores address', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(
            _FakeConnectionRepository(),
          ),
        ],
        child: const MaterialApp(home: ConnectionPage()),
      ),
    );
    await tester.pump();

    expect(find.text('HMusic'), findsOneWidget);
    expect(find.text('连接服务器'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'http://192.168.1.10:8090');
  });
}
