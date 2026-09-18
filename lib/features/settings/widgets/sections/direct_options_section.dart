import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/hmusic_notice.dart';
import '../../../../shared/widgets/hmusic_inline_notice.dart';
import '../../models/config_options.dart';
import '../../models/direct_options.dart';
import '../../models/server_config.dart';
import '../../view_models/direct_options_view_model.dart';
import '../settings_form_card.dart';
import 'direct_speaker_options.dart';
import 'settings_choice_field.dart';

class DirectOptionsSection extends ConsumerStatefulWidget {
  const DirectOptionsSection({this.localOnly = false, super.key});
  final bool localOnly;
  @override
  ConsumerState<DirectOptionsSection> createState() =>
      _DirectOptionsSectionState();
}

class _DirectOptionsSectionState extends ConsumerState<DirectOptionsSection> {
  final _host = TextEditingController(), _models = TextEditingController();
  String _quality = '320k', _search = 'qqFirst', _resolve = 'originalFirst';
  bool _qqDirect = false;

  @override
  void initState() {
    super.initState();
    final options = ref.read(directOptionsViewModelProvider).options;
    if (options != null) {
      _fill(options);
    } else {
      unawaited(
        Future<void>.microtask(
          () => ref.read(directOptionsViewModelProvider.notifier).load(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _host.dispose();
    _models.dispose();
    super.dispose();
  }

  void _fill(DirectOptions options) {
    _quality = options.config.defaultQuality;
    _search = options.config.searchStrategy;
    _resolve = options.config.resolveStrategy;
    _qqDirect = options.qqDirect;
    _host.text = options.proxyHost;
    _models.text = options.config.extraPlayMusicModels.join(', ');
  }

  Future<void> _save() => ref
      .read(directOptionsViewModelProvider.notifier)
      .save(
        DirectOptions(
          config: ServerConfig(
            serverName: '本机直连',
            defaultQuality: _quality,
            searchStrategy: _search,
            resolveStrategy: _resolve,
            extraPlayMusicModels: _models.text.split(RegExp(r'[,，\s]+')),
          ),
          qqDirect: _qqDirect,
          proxyHost: _host.text,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directOptionsViewModelProvider);
    ref.listen(directOptionsViewModelProvider, (previous, next) {
      if (next.options != null && previous?.options != next.options) {
        setState(() => _fill(next.options!));
      }
    });
    if (state.options == null) {
      return Column(
        children: [
          Text(state.message ?? '加载中…'),
          if (state.message != null)
            TextButton(
              onPressed: ref.read(directOptionsViewModelProvider.notifier).load,
              child: const Text('重试'),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsFormCard(
          title: '播放偏好',
          description: '音质和平台顺序将用于之后的搜索与点播。',
          child: Column(
            children: [
              SettingsChoiceField(
                label: '默认音质',
                value: _quality,
                options: kQualityOptions,
                hint: '音源不支持所选音质时，会尝试可用档位。',
                onChanged: state.saving
                    ? null
                    : (v) => setState(() => _quality = v),
              ),
              const SizedBox(height: 20),
              SettingsChoiceField(
                label: '搜索优先平台',
                value: _search,
                options: kSearchStrategyOptions,
                onChanged: state.saving
                    ? null
                    : (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 20),
              SettingsChoiceField(
                label: '播放解析策略',
                value: _resolve,
                options: kResolveStrategyOptions,
                onChanged: state.saving
                    ? null
                    : (v) => setState(() => _resolve = v),
              ),
            ],
          ),
        ),
        if (!widget.localOnly) ...[
          const SizedBox(height: 16),
          DirectSpeakerOptions(
            qqDirect: _qqDirect,
            onQqDirectChanged: (v) => setState(() => _qqDirect = v),
            host: _host,
            extraModels: _models,
            enabled: !state.saving,
          ),
        ],
        const SizedBox(height: 20),
        if (state.message != null) ...[
          HMusicInlineNotice(
            state.failed
                ? HMusicNotice.error(state.message!)
                : HMusicNotice.success(state.message!),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          onPressed: state.saving ? null : _save,
          child: Text(
            state.saving
                ? '保存中…'
                : widget.localOnly
                ? '保存播放偏好'
                : '保存直连配置',
          ),
        ),
      ],
    );
  }
}
