import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chart.dart';
import '../models/chart_catalog.dart';
import '../models/chart_home_preferences.dart';
import '../view_models/chart_home_preferences_view_model.dart';

Future<void> showChartHomeEditor(BuildContext context, List<Chart> charts) =>
    showDialog<void>(
      context: context,
      builder: (_) => ChartHomeEditor(charts: charts),
    );

class ChartHomeEditor extends ConsumerStatefulWidget {
  const ChartHomeEditor({required this.charts, super.key});
  final List<Chart> charts;

  @override
  ConsumerState<ChartHomeEditor> createState() => _ChartHomeEditorState();
}

class _ChartHomeEditorState extends ConsumerState<ChartHomeEditor> {
  late ChartHomePreferences _draft;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(chartHomePreferencesProvider).ensureOne(widget.charts);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(chartHomePreferencesProvider.notifier)
          .save(_draft, charts: widget.charts);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final charts = _draft.sorted(widget.charts);
    final defaults = _draft.defaults(widget.charts);
    final selected = _draft.selected(widget.charts);
    final lastId = selected.length == 1 ? selected.single.id : null;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('首页推荐管理'),
        content: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('至少保留一个推荐榜单。拖动右侧手柄排序，隐藏后仍可在平台分类查看。'),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: charts.length,
                  onReorder: (oldIndex, newIndex) {
                    if (!_saving) {
                      setState(
                        () => _draft = _draft.reorder(
                          widget.charts,
                          oldIndex,
                          newIndex,
                        ),
                      );
                    }
                  },
                  itemBuilder: (context, index) {
                    final chart = charts[index];
                    return ListTile(
                      key: ValueKey(chart.id),
                      contentPadding: EdgeInsets.zero,
                      leading: Switch.adaptive(
                        value: _draft.enabled(chart.id, defaults),
                        onChanged: _saving || chart.id == lastId
                            ? null
                            : (value) => setState(
                                () => _draft = _draft.show(chart.id, value),
                              ),
                      ),
                      title: Text(chart.name),
                      subtitle: Text(
                        chart.id == lastId
                            ? '${chartSourceLabel(chart)} · 至少保留一项'
                            : chartSourceLabel(chart),
                      ),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        enabled: !_saving,
                        child: Semantics(
                          label: '拖动排序：${chart.name}',
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () => setState(() => _draft = const ChartHomePreferences()),
            child: const Text('恢复默认'),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _saving || selected.isEmpty ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
    );
  }
}
