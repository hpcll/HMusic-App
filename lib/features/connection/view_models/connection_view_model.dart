import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/session/session_providers.dart';
import '../data/api_connection_repository.dart';
import '../data/lan_server_scanner.dart';
import '../models/connection_view_state.dart';

final NotifierProvider<ConnectionViewModel, ConnectionViewState>
connectionViewModelProvider =
    NotifierProvider<ConnectionViewModel, ConnectionViewState>(
      ConnectionViewModel.new,
    );

class ConnectionViewModel extends Notifier<ConnectionViewState> {
  @override
  ConnectionViewState build() => const ConnectionViewState();

  Future<void> loadSavedAddress() async {
    final address = await ref
        .read(connectionRepositoryProvider)
        .loadSavedAddress();
    if (address != null) state = state.copyWith(suggestedAddress: address);
  }

  // 冷启动接续：存过地址就先原样连回去，成功即直奔登录页（token 还在就自动放行）。
  // 用户抱怨的「每次打开都要重新登录」有一半是这里缺失造成的——每次开屏都得从
  // 发现列表点一台，而点到的地址形态（mDNS 给 host.local、扫段给 IP）和上次存的
  // 不一致时 connect() 会当成换服务器清掉 token，于是又要输一遍账号密码。
  // 失败不报错：静默回落到自动发现（换网/服务端没开机就是这条路）。
  Future<bool> resumeSaved() async {
    await loadSavedAddress();
    final saved = state.suggestedAddress;
    if (saved.isEmpty) return false;
    state = state.copyWith(restoring: true, clearError: true);
    try {
      return await connect(saved);
    } finally {
      state = state.copyWith(restoring: false, clearError: true);
    }
  }

  // 局域网自动发现：连接页开屏即调，结果逐台追加。扫描失败静默收尾——
  // errorMessage 留给「连接」动作本身，扫不到只是回到手输路径。
  Future<void> discover() async {
    if (state.discovering) return;
    state = state.copyWith(
      discovering: true,
      discovered: const <DiscoveredServer>[],
    );
    try {
      await for (final server in ref.read(lanServerScannerProvider).scan()) {
        state = state.copyWith(
          discovered: <DiscoveredServer>[...state.discovered, server],
        );
      }
    } catch (_) {
      // 无网卡/权限拒绝等一律安静回落手输。
    } finally {
      state = state.copyWith(discovering: false, discoverCompleted: true);
    }
  }

  Future<bool> connect(String input) async {
    if (state.isConnecting) return false;
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      clearError: true,
    );
    try {
      final result = await ref
          .read(connectionRepositoryProvider)
          .connect(input);
      state = state.copyWith(
        status: ConnectionStatus.connected,
        connectedBase: result.serverBase,
        serverName: result.serverInfo.name,
        clearError: true,
      );
      // 连到（可能不同的）服务器是全新会话起点：复位上一会话的 401 失效标志。
      ref.read(sessionControllerProvider).markValid();
      return true;
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        status: ConnectionStatus.idle,
        errorMessage: failure.message,
      );
    } on Exception catch (error) {
      state = state.copyWith(
        status: ConnectionStatus.idle,
        errorMessage: error.toString(),
      );
    } catch (error) {
      // Error（类型错误、断言…）不是 Exception，不兜住就会把状态永久留在
      // connecting，表现为按钮一直转、点不动也不报错。宁可报得难看也不能卡死。
      state = state.copyWith(
        status: ConnectionStatus.idle,
        errorMessage: '连接失败：$error',
      );
    }
    return false;
  }
}
