import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/upgrade/app_update_badge.dart';
import 'package:hmusic/features/settings/data/api_mi_account_repository.dart';
import 'package:hmusic/features/settings/models/settings_menu_state.dart';
import 'package:hmusic/features/settings/models/settings_section.dart';
import 'package:hmusic/features/settings/view_models/settings_menu_view_model.dart';
import 'package:hmusic/features/settings/views/settings_page.dart';
import 'package:hmusic/features/settings/widgets/sections/mi_account_section.dart';
import 'package:hmusic/features/settings/widgets/sections/mi_password_tab.dart';
import 'package:hmusic/features/settings/widgets/settings_menu.dart';
import 'package:hmusic/features/settings/widgets/settings_section_subpage.dart';

import 'support/fake_mi_account_repository.dart';

class _QuietSettingsMenu extends SettingsMenuViewModel {
  _QuietSettingsMenu({this.initialSection = SettingsSection.security});

  final SettingsSection? initialSection;

  @override
  SettingsMenuState build() => SettingsMenuState(section: initialSection);

  @override
  Future<void> loadSummary() async {}
}

class _NoUpdateBadge extends AppUpdateBadge {
  @override
  String build() => '';
}

Future<void> _pumpSettings(
  WidgetTester tester,
  ValueNotifier<double> contentWidth, {
  double textScale = 1,
  SettingsSection? initialSection = SettingsSection.security,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsMenuViewModelProvider.overrideWith(
          () => _QuietSettingsMenu(initialSection: initialSection),
        ),
        appUpdateBadgeProvider.overrideWith(_NoUpdateBadge.new),
        miAccountRepositoryProvider.overrideWithValue(
          FakeMiAccountRepository(),
        ),
      ],
      child: MaterialApp(
        theme: HMusicTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: contentWidth,
            builder: (context, width, child) => Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child),
            ),
            child: const SettingsPage(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('默认小米面板输入后宽窄往返保留草稿，窄页仍能返回菜单', (tester) async {
    final width = ValueNotifier<double>(900);
    addTearDown(width.dispose);
    await _pumpSettings(tester, width, initialSection: null);
    expect(find.byType(MiAccountSectionView), findsOneWidget);
    await tester.tap(find.text('账号密码'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(MiPasswordTab),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'listener@example.test');
    await tester.enterText(fields.at(1), 'test-draft-secret');

    width.value = 620;
    await tester.pumpAndSettle();
    expect(find.byType(SettingsSectionSubpage), findsOneWidget);
    expect(find.byType(MiPasswordTab), findsOneWidget);
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      'listener@example.test',
    );

    width.value = 900;
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      'listener@example.test',
    );
    expect(
      tester.widget<TextField>(fields.at(1)).controller!.text,
      'test-draft-secret',
    );

    width.value = 620;
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsMenu), findsOneWidget);
    expect(find.byType(MiAccountSectionView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('初次以窄布局打开默认设置时保留菜单入口', (tester) async {
    final width = ValueNotifier<double>(620);
    addTearDown(width.dispose);
    await _pumpSettings(tester, width, initialSection: null);
    expect(find.byType(SettingsMenu), findsOneWidget);
    expect(find.byType(MiAccountSectionView), findsNothing);
  });

  testWidgets('设置依据实际内容宽度分栏，往返布局保留选中项和输入', (tester) async {
    final width = ValueNotifier<double>(620);
    addTearDown(width.dispose);
    await _pumpSettings(tester, width);
    expect(find.byType(SettingsSectionSubpage), findsOneWidget);
    expect(find.byType(SettingsMenu), findsNothing);
    await tester.enterText(find.byType(TextField).first, '尚未提交的输入');

    width.value = 900;
    await tester.pumpAndSettle();
    expect(find.byType(SettingsSectionSubpage), findsNothing);
    expect(find.byType(SettingsMenu), findsOneWidget);
    expect(
      tester.widget<SettingsMenu>(find.byType(SettingsMenu)).activeSection,
      SettingsSection.security,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '尚未提交的输入',
    );

    width.value = 620;
    await tester.pumpAndSettle();
    expect(find.byType(SettingsSectionSubpage), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '尚未提交的输入',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('两倍文字的设置菜单与正文保持可布局', (tester) async {
    final width = ValueNotifier<double>(900);
    addTearDown(width.dispose);
    await _pumpSettings(tester, width, textScale: 2);
    expect(find.byType(SettingsSectionSubpage), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    width.value = 1200;
    await tester.pumpAndSettle();
    expect(find.byType(SettingsMenu), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
