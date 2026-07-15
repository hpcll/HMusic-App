// 真机/真服务器冒烟测试：对着运行中的 HMusic Server 跑连接契约 + 真实搜索往返。
// 默认跳过（CI 无服务器）；需要时传服务器地址运行：
//   flutter test integration_test/live_server_test.dart \
//     --dart-define=HMUSIC_TEST_SERVER=http://192.168.2.52:8090
//   搜索需鉴权，另传管理员 token（可用 /auth/login 换取）：
//     --dart-define=HMUSIC_TEST_TOKEN=<jwt>
//
// system/info 免鉴权，可无人值守；search 有 token 时才跑。
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/config/server_address_policy.dart';
import 'package:hmusic/core/models/server_info.dart';
import 'package:hmusic/features/search/models/search_result.dart';
import 'package:integration_test/integration_test.dart';

const String _serverEnv = String.fromEnvironment('HMUSIC_TEST_SERVER');
const String _tokenEnv = String.fromEnvironment('HMUSIC_TEST_TOKEN');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final skipNoServer = _serverEnv.isEmpty
      ? '未提供 HMUSIC_TEST_SERVER，跳过真服务器冒烟'
      : false;
  final skipNoToken = _serverEnv.isEmpty || _tokenEnv.isEmpty
      ? '未提供服务器或 HMUSIC_TEST_TOKEN，跳过鉴权搜索'
      : false;

  late Dio dio;
  late Uri base;

  setUpAll(() {
    if (_serverEnv.isEmpty) return;
    base = ServerAddressPolicy.normalize(_serverEnv);
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 12),
      ),
    );
  });

  test('system/info reports a compatible HMusic Server', () async {
    final response = await dio.getUri<Map<String, Object?>>(
      base.replace(path: '/api/v1/system/info'),
    );
    final info = ServerInfo.fromJson(response.data!);
    expect(info.name, 'HMusic Server');
    expect(info.apiVersion, 'v1');
  }, skip: skipNoServer);

  test('search returns tracks for a common keyword', () async {
    final response = await dio.getUri<Map<String, Object?>>(
      base.replace(
        path: '/api/v1/search',
        queryParameters: <String, String>{'q': '周杰伦', 'limit': '10'},
      ),
      options: Options(
        headers: <String, Object?>{'Authorization': 'Bearer $_tokenEnv'},
      ),
    );
    final result = SearchResult.fromJson(response.data!);
    expect(result.tracks, isNotEmpty);
    expect(result.tracks.first.title, isNotEmpty);
    expect(result.tracks.first.source, isNotEmpty);
  }, skip: skipNoToken);
}
