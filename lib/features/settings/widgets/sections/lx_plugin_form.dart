import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/hmusic_card.dart';
import '../../models/config_options.dart';
import '../../models/sources_state.dart';
import '../../view_models/sources_view_model.dart';
import 'settings_field.dart';

// 添加/编辑 LX 插件表单：订阅链接拉取 + 粘贴代码两通道（web 的「选文件」通道需
// file_picker 依赖，粘贴代码已覆盖同一终点，按 YAGNI 省略）。id/name/code/sourceUrl
// 由本地 controller 持有，edit/fetch 从外部改 state.form 时同步回填，用户输入不打断。
class LxPluginFormCard extends ConsumerStatefulWidget {
  const LxPluginFormCard({super.key});

  @override
  ConsumerState<LxPluginFormCard> createState() => _LxPluginFormState();
}

class _LxPluginFormState extends ConsumerState<LxPluginFormCard> {
  final TextEditingController _sourceUrl = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _id = TextEditingController();
  final TextEditingController _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncFromForm(ref.read(sourcesViewModelProvider).form);
  }

  @override
  void dispose() {
    _sourceUrl.dispose();
    _code.dispose();
    _id.dispose();
    _name.dispose();
    super.dispose();
  }

  // 外部改 form（edit/fetch/保存后清空）时回填 controller；值一致则跳过，
  // 避免用户输入 → updateForm → 回填打断光标。
  void _syncFromForm(LxPluginForm form) {
    if (_sourceUrl.text != form.sourceUrl) _sourceUrl.text = form.sourceUrl;
    if (_code.text != form.code) _code.text = form.code;
    if (_id.text != form.id) _id.text = form.id;
    if (_name.text != form.name) _name.text = form.name;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sourcesViewModelProvider.select((s) => s.form), (_, form) {
      _syncFromForm(form);
    });
    final state = ref.watch(sourcesViewModelProvider);
    final notifier = ref.read(sourcesViewModelProvider.notifier);

    return HMusicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SettingsCardTitle('添加 / 编辑插件'),
          const SizedBox(height: 12),
          SettingsField(
            label: '订阅链接（推荐）',
            hint: '服务端会拉取脚本并预填下方表单；保存后列表里可一键「更新」。',
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _sourceUrl,
                    decoration: const InputDecoration(
                      hintText: 'https://…/script?key=xxx',
                    ),
                    onChanged: (v) => notifier.updateForm(sourceUrl: v),
                    onSubmitted: (_) => notifier.fetchFromUrl(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: state.fetching ? null : notifier.fetchFromUrl,
                  child: Text(state.fetching ? '拉取中…' : '拉取'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SettingsField(
            label: '插件代码',
            hint: '或直接粘贴 LX 音源插件的 JavaScript 代码。',
            child: TextField(
              controller: _code,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(hintText: '// LX 音源插件代码…'),
              onChanged: (v) => notifier.updateForm(code: v),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: SettingsField(
                  label: '插件 ID',
                  child: TextField(
                    controller: _id,
                    decoration: const InputDecoration(hintText: '如 liuyin'),
                    onChanged: (v) => notifier.updateForm(id: v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SettingsField(
                  label: '名称',
                  child: TextField(
                    controller: _name,
                    onChanged: (v) => notifier.updateForm(name: v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: SettingsField(
                  label: '默认音质',
                  child: _qualityDropdown(state.form.quality, notifier),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EnabledSwitch(
                  value: state.form.enabled,
                  onChanged: (v) => notifier.updateForm(enabled: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: state.busy ? null : () => notifier.save(),
              child: Text(state.busy ? '保存中…' : '保存插件'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qualityDropdown(String value, SourcesViewModel notifier) {
    final values = kQualityOptions.map(((String, String) o) => o.$1).toSet();
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: <DropdownMenuItem<String>>[
        for (final (v, label) in kQualityOptions)
          DropdownMenuItem<String>(value: v, child: Text(label)),
        if (!values.contains(value))
          DropdownMenuItem<String>(value: value, child: Text(value)),
      ],
      onChanged: (v) {
        if (v != null) notifier.updateForm(quality: v);
      },
    );
  }
}

// 「保存后启用」开关：对齐 web 的 checkbox-field。
class _EnabledSwitch extends StatelessWidget {
  const _EnabledSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsField(
      label: '保存后启用',
      child: Align(
        alignment: Alignment.centerLeft,
        child: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}
