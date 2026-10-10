import 'package:flutter_test/flutter_test.dart';
import 'package:washnlaundrycrm/providers/app_provider.dart';
import 'package:washnlaundrycrm/screens/settings_screen.dart';
import 'package:washnlaundrycrm/widgets/backup_export_panel.dart';

import 'support/router_test_utils.dart';

void main() {
  testWidgets('Settings renders the Backup, Data Import & Export tab and panel', (tester) async {
    final provider = AppProvider(autoLoad: false);
    await tester.pumpWidget(
      hostWithRouter(
        provider,
        const SettingsScreen(initialTab: 'backup-export'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backup, Data Import & Export'), findsWidgets);
    expect(find.byType(BackupExportPanel), findsOneWidget);
    expect(find.text('Full CRM Backup (All Sections)'), findsOneWidget);
    expect(find.text('Download Complete Excel (.xlsx)'), findsOneWidget);
    expect(find.text('Download Full JSON Archive'), findsOneWidget);
    expect(find.text('Staff Roster'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Payroll & Advances'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Credits'), findsOneWidget);
    expect(find.text('Services & Rates'), findsOneWidget);
    // Every section row offers an Import next to its export.
    expect(find.text('Import'), findsNWidgets(8));
    // Customers import/export now lives here, not in its own tab.
    expect(find.text('Customers import/export'), findsNothing);
  });
}
