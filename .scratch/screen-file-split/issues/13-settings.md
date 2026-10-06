# 13 settings_screen.dart (1,104) + data_management_screen.dart (769)

Status: ready-for-agent

- `settings_widgets.dart` — `_SettingsGroup`, `_SettingsIcon`, `_SettingsToggleTile`, `_ThemeColorSwatch`
- `settings_theme_color_sheet.dart`, `settings_monthly_cycle_sheet.dart`
- `settings_ai_export_sheet.dart` — `_showAiFinanceExportSheet`, `_copyAiFinanceSnapshot`, `_buildExportScopeTile`
- data_management: only extract `_buildSectionTitle` / `_buildConfigRow` / `_buildInfoItem` into
  `data_management_widgets.dart` if `build` is still > 400 lines afterwards.
