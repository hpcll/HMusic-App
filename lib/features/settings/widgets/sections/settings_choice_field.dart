import 'package:flutter/material.dart';

import 'settings_field.dart';

class SettingsChoiceField extends StatelessWidget {
  const SettingsChoiceField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
    super.key,
  });
  final String label, value;
  final String? hint;
  final List<(String, String)> options;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => SettingsField(
    label: label,
    hint: hint,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: value,
      isExpanded: true,
      itemHeight: null,
      items: [
        for (final (key, text) in options)
          DropdownMenuItem(
            value: key,
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        if (!options.any((option) => option.$1 == value))
          DropdownMenuItem(value: value, child: Text(value)),
      ],
      onChanged: onChanged == null
          ? null
          : (next) {
              if (next != null) onChanged!(next);
            },
    ),
  );
}
