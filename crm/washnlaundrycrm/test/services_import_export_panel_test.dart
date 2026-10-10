import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/settings_screen.dart';
import 'package:washnlaundrycrm/widgets/services_import_export_panel.dart';

import 'support/router_test_utils.dart';

void main() {
  testWidgets('Services import/export is reached from Backup, Data Import & Export',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1400, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final provider = AppProvider(autoLoad: false);
    await tester.pumpWidget(
      hostWithRouter(
        provider,
        const SettingsScreen(initialTab: 'backup-export'),
      ),
    );
    await tester.pumpAndSettle();

    // No standalone Services tab any more.
    expect(find.text('Services export/import'), findsNothing);

    // The Services & Rates row is the last of 8; its Import opens the panel.
    final importButtons = find.text('Import');
    expect(importButtons, findsNWidgets(8));
    await tester.ensureVisible(importButtons.last);
    await tester.tap(importButtons.last);
    await tester.pumpAndSettle();

    expect(find.byType(ServicesImportExportPanel), findsOneWidget);
    expect(find.text('Export Services to Excel (.xlsx)'), findsOneWidget);
    expect(find.text('Import Services from Excel (.xlsx)'), findsOneWidget);
  });

  testWidgets('Settings has no Sign Out entry', (tester) async {
    final provider = AppProvider(autoLoad: false);
    await tester.pumpWidget(
      hostWithRouter(provider, const SettingsScreen(initialTab: 'backup-export')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign Out'), findsNothing);
  });
}
