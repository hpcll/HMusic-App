import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../data/api_sources_repository.dart';
import '../models/lx_plugin.dart';
import '../models/sources_state.dart';

final NotifierProvider<SourcesViewModel, SourcesState>
sourcesViewModelProvider = NotifierProvider<SourcesViewModel, SourcesState>(
  SourcesViewModel.new,
);

// LX 音源插件（对齐 web SourcesSection）：列表 + health 并发拉取；
// 表单三通道（订阅拉取/选文件/粘贴代码）殊途同归都填 form；保存走全量 upsert。
class SourcesViewModel extends Notifier<SourcesState> {
  @override
  SourcesState build() => const SourcesState();

  Future<void> load() async {
    try {
      final repo = ref.read(sourcesRepositoryProvider);
      // 列表与健康态并发拉取；health 失败不拖垮列表（各自容错在仓库层）。
      final results = await Future.wait(<Future<Object>>[
        repo.listPlugins(),
        repo.loadHealth(),
      ]);
      state = state.copyWith(
        plugins: results[0] as List<LxPlugin>,
        health: results[1] as Map<String, SourceHealth>,
        loaded: true,
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        loaded: true,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  // ===== 表单字段更新（View 的输入框回写到 state.form）=====
  void updateForm({
    String? id,
    String? name,
    String? code,
    String? quality,
    bool? enabled,
    String? sourceUrl,
  }) {
    state = state.copyWith(
      form: state.form.copyWith(
        id: id,
        name: name,
        code: code,
        quality: quality,
        enabled: enabled,
        sourceUrl: sourceUrl,
      ),
    );
  }

  void resetForm() {
    state = state.copyWith(form: const LxPluginForm());
  }

  // 订阅链接代拉脚本，成功后预填表单空位（已有内容不覆盖，对齐 web）。
  Future<void> fetchFromUrl() async {
    final url = state.form.sourceUrl.trim();
    if (url.isEmpty) {
      state = state.copyWith(notice: const HMusicNotice.error('先粘贴订阅链接'));
      return;
    }
    if (state.fetching) return;
    state = state.copyWith(fetching: true);
    try {
      final result = await ref
          .read(sourcesRepositoryProvider)
          .fetchFromUrl(url);
      final form = state.form;
      state = state.copyWith(
        fetching: false,
        form: form.copyWith(
          code: result.code,
          name: form.name.isEmpty && result.name != null
              ? result.name
              : form.name,
          id: form.id.isEmpty ? _suggestId(result.name, url) : form.id,
        ),
        notice: HMusicNotice.success(
          '已拉取「${result.name ?? '未命名脚本'}」'
          '${result.version != null ? ' v${result.version}' : ''}，确认后保存',
        ),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        fetching: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  // 保存/编辑插件（全量 upsert）。成功返回 true 供 View 清空本地输入控制器。
  Future<bool> save() async {
    final form = state.form;
    if (form.id.trim().isEmpty ||
        form.name.trim().isEmpty ||
        form.code.trim().isEmpty) {
      state = state.copyWith(
        notice: const HMusicNotice.error('插件 ID、名称和代码都不能为空'),
      );
      return false;
    }
    if (state.busy) return false;
    state = state.copyWith(busy: true);
    try {
      await ref
          .read(sourcesRepositoryProvider)
          .savePlugin(
            id: form.id.trim(),
            name: form.name.trim(),
            code: form.code,
            enabled: form.enabled,
            defaultQuality: form.quality,
            sourceUrl: form.sourceUrl.trim().isEmpty
                ? null
                : form.sourceUrl.trim(),
          );
      state = state.copyWith(busy: false, form: const LxPluginForm());
      await load();
      state = state.copyWith(notice: const HMusicNotice.success('插件已保存'));
      return true;
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        busy: false,
        notice: HMusicNotice.error(failure.message),
      );
      return false;
    }
  }

  // 切换启用：全量 upsert 需带原代码，先取 code 再回写反转的 enabled。
  Future<void> toggleEnabled(LxPlugin plugin) async {
    try {
      final repo = ref.read(sourcesRepositoryProvider);
      final code = await repo.getCode(plugin.id);
      await repo.savePlugin(
        id: plugin.id,
        name: plugin.name,
        code: code,
        enabled: !plugin.enabled,
        defaultQuality: plugin.defaultQuality,
        sourceUrl: plugin.sourceUrl,
      );
      await load();
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    }
  }

  // 载入既有插件到表单（取全量 code 回填）。
  Future<void> edit(LxPlugin plugin) async {
    try {
      final code = await ref.read(sourcesRepositoryProvider).getCode(plugin.id);
      state = state.copyWith(
        form: LxPluginForm(
          id: plugin.id,
          name: plugin.name,
          code: code,
          quality: plugin.defaultQuality,
          enabled: plugin.enabled,
          sourceUrl: plugin.sourceUrl ?? '',
        ),
        notice: const HMusicNotice.success('插件已载入下方表单，改完保存即可'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    }
  }

  // 按记住的 sourceUrl 一键更新（防连点：updatingId）。
  Future<void> update(LxPlugin plugin) async {
    if (state.updatingId.isNotEmpty) return;
    state = state.copyWith(updatingId: plugin.id);
    try {
      await ref.read(sourcesRepositoryProvider).updatePlugin(plugin.id);
      await load();
      state = state.copyWith(
        notice: HMusicNotice.success('「${plugin.name}」已从订阅链接更新'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    } finally {
      state = state.copyWith(updatingId: '');
    }
  }

  Future<void> test(LxPlugin plugin) async {
    try {
      final message = await ref
          .read(sourcesRepositoryProvider)
          .testPlugin(plugin.id);
      await load();
      state = state.copyWith(
        notice: HMusicNotice.success(message.isEmpty ? '插件加载测试通过' : message),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    }
  }

  Future<void> delete(LxPlugin plugin) async {
    try {
      await ref.read(sourcesRepositoryProvider).deletePlugin(plugin.id);
      await load();
      state = state.copyWith(notice: const HMusicNotice.success('插件已删除'));
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }

  // 订阅拉取后给插件 ID 默认值：优先脚本名 ASCII slug，为空退回域名 slug（对齐 web）。
  String _suggestId(String? name, String url) {
    final fromName = _slug(name ?? '');
    if (fromName.isNotEmpty) return fromName;
    final host = Uri.tryParse(url)?.host ?? '';
    final fromHost = _slug(host.replaceAll('.', '-'));
    return fromHost.isNotEmpty ? fromHost : 'lx-plugin';
  }

  String _slug(String text) {
    final lowered = text.toLowerCase();
    final replaced = lowered.replaceAll(RegExp(r'[^a-z0-9_-]+'), '-');
    final trimmed = replaced.replaceAll(RegExp(r'^-+|-+$'), '');
    return trimmed.length > 32 ? trimmed.substring(0, 32) : trimmed;
  }
}
