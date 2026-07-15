import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../shared/widgets/hmusic_card.dart';
import '../../models/config_options.dart';
import '../../models/server_config.dart';
import '../../view_models/config_view_model.dart';
import 'settings_field.dart';

// 运行配置子页：名称/音质/搜索策略/解析策略/直连型号，整卡表单一键保存。
// 表单值持在本地，config 每次到达（首载或保存回显）都重填，服务端为权威。
class ConfigSectionView extends ConsumerStatefulWidget {
  const ConfigSectionView({super.key});

  @override
  ConsumerState<ConfigSectionView> createState() => _ConfigSectionViewState();
}

class _ConfigSectionViewState extends ConsumerState<ConfigSectionView> {
  final TextEditingController _serverName = TextEditingController();
  final TextEditingController _extraModels = TextEditingController();
  String _quality = '320k';
  String _searchStrategy = 'qqFirst';
  String _resolveStrategy = 'originalFirst';

  @override
  void initState() {
    super.initState();
    final current = ref.read(configViewModelProvider).config;
    if (current != null) {
      _fill(current);
    } else {
      unawaited(
        Future<void>.microtask(
          () => ref.read(configViewModelProvider.notifier).load(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _serverName.dispose();
    _extraModels.dispose();
    super.dispose();
  }

  void _fill(ServerConfig config) {
    _serverName.text = config.serverName;
    _extraModels.text = config.extraPlayMusicModels.join(', ');
    _quality = config.defaultQuality;
    _searchStrategy = config.searchStrategy;
    _resolveStrategy = config.resolveStrategy;
  }

  void _save() {
    unawaited(
      ref
          .read(configViewModelProvider.notifier)
          .save(
            serverName: _serverName.text,
            defaultQuality: _quality,
            searchStrategy: _searchStrategy,
            resolveStrategy: _resolveStrategy,
            extraModelsText: _extraModels.text,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(configViewModelProvider.select((s) => s.config), (_, next) {
      if (next != null) setState(() => _fill(next));
    });
    final state = ref.watch(configViewModelProvider);
    if (state.config == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text('加载中…', style: TextStyle(color: context.palette.muted)),
        ),
      );
    }

    return HMusicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SettingsField(
            label: '服务端名称',
            child: TextField(controller: _serverName),
          ),
          const SizedBox(height: 16),
          SettingsField(
            label: '默认音质',
            hint: '点播与下载的首选档，取不到时自动逐档回退。',
            child: _dropdown(
              kQualityOptions,
              _quality,
              (v) => setState(() => _quality = v),
            ),
          ),
          const SizedBox(height: 16),
          SettingsField(
            label: '搜索策略',
            hint: '决定聚合搜索结果里哪家平台的歌排在前面。',
            child: _dropdown(
              kSearchStrategyOptions,
              _searchStrategy,
              (v) => setState(() => _searchStrategy = v),
            ),
          ),
          const SizedBox(height: 16),
          SettingsField(
            label: '解析策略',
            hint: '选某平台优先时，先在该平台匹配同一首歌取播放链接，失败回落歌曲原平台。',
            child: _dropdown(
              kResolveStrategyOptions,
              _resolveStrategy,
              (v) => setState(() => _resolveStrategy = v),
            ),
          ),
          const SizedBox(height: 16),
          SettingsField(
            label: '自定义直连播放型号',
            hint: '某型号小爱直连播放没声音时才填，内置常见型号已适配。',
            child: TextField(
              controller: _extraModels,
              decoration: const InputDecoration(
                hintText: '型号逗号分隔，如 L20A, X20C',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: state.saving ? null : _save,
              child: Text(state.saving ? '保存中…' : '保存配置'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
    List<(String, String)> options,
    String value,
    ValueChanged<String> onChanged,
  ) {
    // 未知值（服务端新增枚举）临时补入选项，避免 Dropdown 断言崩溃。
    final values = options.map(((String, String) o) => o.$1).toSet();
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: <DropdownMenuItem<String>>[
        for (final (v, label) in options)
          DropdownMenuItem<String>(value: v, child: Text(label)),
        if (!values.contains(value))
          DropdownMenuItem<String>(value: value, child: Text(value)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
