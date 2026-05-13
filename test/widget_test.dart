import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minvielle_ops/main.dart';

void main() {
  testWidgets('navigates from work list to record detail', (tester) async {
    await tester.pumpWidget(
      MinvielleOpsApp(store: OpsStore.seeded(_testRecords())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operations command'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(find.text('Work orders'), findsOneWidget);
    await tester.tap(find.text('Replace air handler filters'));
    await tester.pumpAndSettle();

    expect(find.text('Operational notes'), findsOneWidget);
    expect(find.textContaining('Maintenance window'), findsOneWidget);
  });

  testWidgets('creates a local work record', (tester) async {
    final store = OpsStore.seeded(_testRecords());
    await tester.pumpWidget(MinvielleOpsApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('titleField')),
      'Inspect loading bay lights',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveRecordButton')));
    await tester.pumpAndSettle();

    expect(find.text('Inspect loading bay lights'), findsOneWidget);
    expect(
      store.records.any(
        (record) => record.title == 'Inspect loading bay lights',
      ),
      isTrue,
    );
  });
}

List<OpsRecord> _testRecords() {
  return [
    OpsRecord(
      id: 'test-work',
      type: RecordType.work,
      title: 'Replace air handler filters',
      owner: 'Facility lead',
      site: 'North wing',
      status: RecordStatus.inProgress,
      priority: 'High',
      dueDate: DateTime(2026, 5, 14),
      notes: 'Maintenance window before tenant arrival.',
    ),
    OpsRecord(
      id: 'test-booking',
      type: RecordType.facility,
      title: 'Reserve training room',
      owner: 'Front office',
      site: 'Conference suite A',
      status: RecordStatus.scheduled,
      priority: 'Medium',
      dueDate: DateTime(2026, 5, 15),
      notes: 'Prepare seating and projector.',
    ),
  ];
}
