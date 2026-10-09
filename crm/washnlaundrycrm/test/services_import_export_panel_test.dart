import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/settings_screen.dart';
import 'package:washnlaundrycrm/widgets/services_import_export_panel.dart';

import 'support/router_test_utils.dart';

void main() {
  testWidgets('Settings renders Services export/import tab and panel', (tester) async {
    final provider = AppProvider(autoLoad: false);
    await tester.pumpWidget(
      hostWithRouter(
        provider,
        const SettingsScreen(initialTab: 'services-import-export'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Services export/import'), findsWidgets);
    expect(find.byType(ServicesImportExportPanel), findsOneWidget);
    expect(find.text('Export Services Catalogue'), findsOneWidget);
    expect(find.text('Import Services Catalogue'), findsOneWidget);
    expect(find.text('Export as CSV'), findsOneWidget);
    expect(find.text('Export as JSON'), findsOneWidget);
    expect(find.text('Import Services File'), findsOneWidget);
  });
}
