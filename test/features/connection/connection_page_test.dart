import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/core/models/server_info.dart';
import 'package:hmusic/features/auth/views/auth_page.dart';
import 'package:hmusic/features/connection/data/api_connection_repository.dart';
import 'package:hmusic/features/connection/data/connection_repository.dart';
import 'package:hmusic/features/connection/models/connection_result.dart';
import 'package:hmusic/features/connection/views/connection_page.dart';
import 'package:hmusic/shared/widgets/brand_mark.dart';

class _FakeConnectionRepository implements ConnectionRepository {
  static const String savedAddress = 'http://192.168.1.10:8090';
  final List<String> connectInputs = <String>[];

  @override
  Future<ConnectionResult> connect(String input) async {
    connectInputs.add(input);
    return ConnectionResult(
      serverBase: Uri.parse(input),
      serverInfo: const ServerInfo(
        name: 'HMusic Server',
        version: '0.1.0',
        apiVersion: 'v1',
      ),
    );
  }

  @override
  Future<String?> loadSavedAddress() async => savedAddress;
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

    // 品牌位是完整字标图（字形含 H + Music），页面不再有 "HMusic" 文本。
    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(find.text('连接服务器'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'http://192.168.1.10:8090');
  });

  testWidgets('connect button submits address and navigates to auth', (
    tester,
  ) async {
    final repository = _FakeConnectionRepository();
    final router = GoRouter(
      initialLocation: ConnectionPage.path,
      routes: <RouteBase>[
        GoRoute(
          path: ConnectionPage.path,
          builder: (context, state) => const ConnectionPage(),
        ),
        GoRoute(
          path: AuthPage.path,
          builder: (context, state) =>
              const Scaffold(body: Text('auth destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [connectionRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('连接服务器'));
    await tester.pumpAndSettle();

    expect(repository.connectInputs, <String>['http://192.168.1.10:8090']);
    expect(find.text('auth destination'), findsOneWidget);
  });
}
