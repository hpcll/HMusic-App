import '../../../shared/models/hmusic_notice.dart';
import 'lx_plugin.dart';

// LX 音源插件子页状态（对齐 web SourcesSection）。列表 + health + 编辑表单。
// 表单字段独立成一组，编辑既有插件时回填、保存/拉取后清空。
class SourcesState {
  const SourcesState({
    this.plugins = const <LxPlugin>[],
    this.health = const <String, SourceHealth>{},
    this.loaded = false,
    this.busy = false,
    this.fetching = false,
    this.updatingId = '',
    this.form = const LxPluginForm(),
    this.notice,
  });

  final List<LxPlugin> plugins;

  // id → 健康态，缺项按 unknown 处理。
  final Map<String, SourceHealth> health;
  final bool loaded;

  // 保存插件中（表单提交）。
  final bool busy;

  // 订阅链接拉取中。
  final bool fetching;

  // 正在一键更新的插件 id，防连点。
  final String updatingId;
  final LxPluginForm form;
  final HMusicNotice? notice;

  SourceHealth healthOf(String id) => health[id] ?? SourceHealth.unknown;

  SourcesState copyWith({
    List<LxPlugin>? plugins,
    Map<String, SourceHealth>? health,
    bool? loaded,
    bool? busy,
    bool? fetching,
    String? updatingId,
    LxPluginForm? form,
    HMusicNotice? notice,
    bool clearNotice = false,
  }) {
    return SourcesState(
      plugins: plugins ?? this.plugins,
      health: health ?? this.health,
      loaded: loaded ?? this.loaded,
      busy: busy ?? this.busy,
      fetching: fetching ?? this.fetching,
      updatingId: updatingId ?? this.updatingId,
      form: form ?? this.form,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

// 添加/编辑插件表单。三通道（订阅拉取/选文件/粘贴代码）殊途同归都填这里。
class LxPluginForm {
  const LxPluginForm({
    this.id = '',
    this.name = '',
    this.code = '',
    this.quality = '320k',
    this.enabled = true,
    this.sourceUrl = '',
  });

  final String id;
  final String name;
  final String code;
  final String quality;
  final bool enabled;
  final String sourceUrl;

  LxPluginForm copyWith({
    String? id,
    String? name,
    String? code,
    String? quality,
    bool? enabled,
    String? sourceUrl,
  }) {
    return LxPluginForm(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      quality: quality ?? this.quality,
      enabled: enabled ?? this.enabled,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }
}
