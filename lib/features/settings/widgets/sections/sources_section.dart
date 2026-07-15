import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../core/audio/models/hmusic_playback_state.dart';
import '../../../../shared/widgets/hmusic_card.dart';
import '../../../../shared/widgets/state_dot.dart';
import '../../models/lx_plugin.dart';
import '../../view_models/sources_view_model.dart';
import 'lx_plugin_form.dart';

// LX 音源插件子页：插件列表（启用开关 / 测试 / 编辑 / 更新 / 删除）+ 添加编辑表单。
// 对齐 web SourcesSection。列表卡与表单分开，各自私有组件守 View 行数门禁。
class SourcesSectionView extends ConsumerStatefulWidget {
  const SourcesSectionView({super.key});

  @override
  ConsumerState<SourcesSectionView> createState() => _SourcesSectionViewState();
}

class _SourcesSectionViewState extends ConsumerState<SourcesSectionView> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(sourcesViewModelProvider.notifier).load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(sourcesViewModelProvider);
    final notifier = ref.read(sourcesViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!state.loaded)
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 16),
            child: Center(
              child: Text('加载中…', style: TextStyle(color: palette.muted)),
            ),
          )
        else if (state.plugins.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 16),
            child: Center(
              child: Text(
                '还没有 LX 插件，在下方添加一个音源插件',
                style: TextStyle(color: palette.muted),
              ),
            ),
          )
        else
          for (final plugin in state.plugins) ...<Widget>[
            _PluginCard(
              plugin: plugin,
              health: state.healthOf(plugin.id),
              updating: state.updatingId == plugin.id,
              onToggle: () => notifier.toggleEnabled(plugin),
              onTest: () => notifier.test(plugin),
              onEdit: () => notifier.edit(plugin),
              onUpdate: () => notifier.update(plugin),
              onDelete: () => notifier.delete(plugin),
            ),
            const SizedBox(height: 12),
          ],
        const LxPluginFormCard(),
      ],
    );
  }
}

// 插件卡：名称 + 「id · 音质 · 健康态」+ 启用开关 + 操作按钮行。
class _PluginCard extends StatelessWidget {
  const _PluginCard({
    required this.plugin,
    required this.health,
    required this.updating,
    required this.onToggle,
    required this.onTest,
    required this.onEdit,
    required this.onUpdate,
    required this.onDelete,
  });

  final LxPlugin plugin;
  final SourceHealth health;
  final bool updating;
  final VoidCallback onToggle;
  final VoidCallback onTest;
  final VoidCallback onEdit;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return HMusicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      plugin.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: palette.textStrong,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        StateDot(_healthDot(health), size: 7),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${plugin.id} · ${plugin.defaultQuality} · 健康 ${_healthLabel(health)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: plugin.enabled, onChanged: (_) => onToggle()),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              OutlinedButton(onPressed: onTest, child: const Text('测试')),
              OutlinedButton(onPressed: onEdit, child: const Text('编辑')),
              if (plugin.sourceUrl != null)
                OutlinedButton(
                  onPressed: updating ? null : onUpdate,
                  child: Text(updating ? '更新中…' : '更新'),
                ),
              TextButton(
                onPressed: onDelete,
                style: TextButton.styleFrom(foregroundColor: palette.danger),
                child: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 健康态状态点：ok=青绿（音源可用，属「正在发生的事」），failed=danger，unknown=muted。
  PlaybackStatus _healthDot(SourceHealth health) {
    return switch (health) {
      SourceHealth.ok => PlaybackStatus.playing,
      SourceHealth.failed => PlaybackStatus.error,
      SourceHealth.unknown => PlaybackStatus.idle,
    };
  }

  String _healthLabel(SourceHealth health) {
    return switch (health) {
      SourceHealth.ok => 'ok',
      SourceHealth.failed => 'failed',
      SourceHealth.unknown => 'unknown',
    };
  }
}
