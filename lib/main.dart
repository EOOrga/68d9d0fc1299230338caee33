import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appName = 'MINVIELLE FRANCOIS YVES';
const _screenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');
const _storageKey = 'minvielle_ops_records_v1';

void main() {
  runApp(const MinvielleOpsApp());
}

class RecordType {
  static const work = 'work';
  static const facility = 'facility';
  static const shipment = 'shipment';
  static const compliance = 'compliance';

  static const values = [work, facility, shipment, compliance];

  static String label(String type) {
    return switch (type) {
      work => 'Work order',
      facility => 'Facility booking',
      shipment => 'Shipment',
      compliance => 'Compliance report',
      _ => 'Record',
    };
  }

  static String plural(String type) {
    return switch (type) {
      work => 'Work orders',
      facility => 'Facility bookings',
      shipment => 'Shipment log',
      compliance => 'Compliance reports',
      _ => 'Records',
    };
  }

  static IconData icon(String type) {
    return switch (type) {
      work => Icons.assignment_rounded,
      facility => Icons.meeting_room_rounded,
      shipment => Icons.local_shipping_rounded,
      compliance => Icons.fact_check_rounded,
      _ => Icons.folder_rounded,
    };
  }
}

class RecordStatus {
  static const queued = 'Queued';
  static const scheduled = 'Scheduled';
  static const inProgress = 'In progress';
  static const blocked = 'Blocked';
  static const closed = 'Closed';

  static const values = [queued, scheduled, inProgress, blocked, closed];
}

class OpsRecord {
  OpsRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.owner,
    required this.site,
    required this.status,
    required this.priority,
    required this.dueDate,
    required this.notes,
  });

  final String id;
  final String type;
  final String title;
  final String owner;
  final String site;
  final String status;
  final String priority;
  final DateTime dueDate;
  final String notes;

  OpsRecord copyWith({
    String? title,
    String? owner,
    String? site,
    String? status,
    String? priority,
    DateTime? dueDate,
    String? notes,
  }) {
    return OpsRecord(
      id: id,
      type: type,
      title: title ?? this.title,
      owner: owner ?? this.owner,
      site: site ?? this.site,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'owner': owner,
      'site': site,
      'status': status,
      'priority': priority,
      'dueDate': dueDate.toIso8601String(),
      'notes': notes,
    };
  }

  factory OpsRecord.fromJson(Map<String, dynamic> json) {
    return OpsRecord(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: json['type'] as String? ?? RecordType.work,
      title: json['title'] as String? ?? 'Untitled record',
      owner: json['owner'] as String? ?? 'Operations',
      site: json['site'] as String? ?? 'Main site',
      status: json['status'] as String? ?? RecordStatus.queued,
      priority: json['priority'] as String? ?? 'Medium',
      dueDate:
          DateTime.tryParse(json['dueDate'] as String? ?? '') ??
          DateTime(2026, 5, 12),
      notes: json['notes'] as String? ?? '',
    );
  }
}

class OpsStore extends ChangeNotifier {
  OpsStore({List<OpsRecord>? seedRecords, bool persist = true})
    : _records = List<OpsRecord>.from(seedRecords ?? const []),
      _persist = persist;

  factory OpsStore.seeded(List<OpsRecord> records) {
    return OpsStore(seedRecords: records, persist: false);
  }

  final bool _persist;
  List<OpsRecord> _records;
  SharedPreferences? _preferences;

  List<OpsRecord> get records {
    return List.unmodifiable(_records);
  }

  Future<void> initialize() async {
    if (!_persist) {
      return;
    }

    _preferences = await SharedPreferences.getInstance();
    final raw = _preferences!.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _records = _starterRecords();
      await _save();
      notifyListeners();
      return;
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    _records = decoded
        .whereType<Map<String, dynamic>>()
        .map(OpsRecord.fromJson)
        .toList();
    notifyListeners();
  }

  List<OpsRecord> byType(String type) {
    return _records
        .where((record) => record.type == type)
        .toList(growable: false);
  }

  OpsRecord? findById(String id) {
    for (final record in _records) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  int countWhere(bool Function(OpsRecord record) test) {
    return _records.where(test).length;
  }

  Future<void> addRecord(OpsRecord record) async {
    _records = [record, ..._records];
    notifyListeners();
    await _save();
  }

  Future<void> updateRecord(OpsRecord updated) async {
    _records = [
      for (final record in _records)
        if (record.id == updated.id) updated else record,
    ];
    notifyListeners();
    await _save();
  }

  Future<void> removeRecord(String id) async {
    _records = _records
        .where((record) => record.id != id)
        .toList(growable: false);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    if (!_persist || _preferences == null) {
      return;
    }
    final raw = jsonEncode(_records.map((record) => record.toJson()).toList());
    await _preferences!.setString(_storageKey, raw);
  }
}

class OpsScope extends InheritedNotifier<OpsStore> {
  const OpsScope({
    required OpsStore super.notifier,
    required super.child,
    super.key,
  });

  static OpsStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<OpsScope>();
    assert(scope != null, 'OpsScope was not found in the widget tree.');
    return scope!.notifier!;
  }
}

class MinvielleOpsApp extends StatefulWidget {
  const MinvielleOpsApp({super.key, this.store});

  final OpsStore? store;

  @override
  State<MinvielleOpsApp> createState() => _MinvielleOpsAppState();
}

class _MinvielleOpsAppState extends State<MinvielleOpsApp> {
  late final OpsStore _store;
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _store =
        widget.store ??
        OpsStore(
          seedRecords: _screenshotMode ? _starterRecords() : null,
          persist: !_screenshotMode,
        );
    _ready = _store.initialize();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        return OpsScope(
          notifier: _store,
          child: MaterialApp(
            title: appName,
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            home: snapshot.connectionState == ConnectionState.done
                ? const OperationsShell()
                : const _LoadingScreen(),
          ),
        );
      },
    );
  }
}

ThemeData _buildTheme() {
  const seed = Color(0xFF2D6A73);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
    primary: const Color(0xFF244E5F),
    secondary: const Color(0xFF2F7A73),
    tertiary: const Color(0xFFD7A442),
    surface: const Color(0xFFF7FAF9),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF7FAF9),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Color(0xFFF7FAF9),
      foregroundColor: Color(0xFF17252B),
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE0E7E6)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD6E0DF)),
      ),
    ),
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class OperationsShell extends StatefulWidget {
  const OperationsShell({super.key});

  @override
  State<OperationsShell> createState() => _OperationsShellState();
}

class _OperationsShellState extends State<OperationsShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final typeForAction = switch (_index) {
      1 => RecordType.work,
      2 => RecordType.facility,
      3 => RecordType.shipment,
      4 => RecordType.compliance,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('MINVIELLE Ops'),
        actions: [
          IconButton(
            tooltip: 'Privacy',
            onPressed: () => setState(() => _index = 4),
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          RecordListScreen(type: RecordType.work),
          RecordListScreen(type: RecordType.facility),
          RecordListScreen(type: RecordType.shipment),
          MoreScreen(),
        ],
      ),
      floatingActionButton: typeForAction == null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('newRecordButton'),
              onPressed: () => _openForm(context, typeForAction),
              icon: const Icon(Icons.add),
              label: const Text('New'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Work',
          ),
          NavigationDestination(
            icon: Icon(Icons.meeting_room_outlined),
            selectedIcon: Icon(Icons.meeting_room_rounded),
            label: 'Rooms',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping_rounded),
            label: 'Ship',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, String type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RecordFormPage(initialType: type),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = OpsScope.of(context);
    final active = store.countWhere(
      (record) => record.status != RecordStatus.closed,
    );
    final blocked = store.countWhere(
      (record) => record.status == RecordStatus.blocked,
    );
    final shipments = store.byType(RecordType.shipment).length;
    final compliance = store.byType(RecordType.compliance).length;
    final nextRecords = store.records.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Image.asset(
                'docs/featured.png',
                height: 168,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x0017252B), Color(0xDD17252B)],
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Operations command',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      appName,
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _MetricGrid(
          metrics: [
            _MetricData('Active tasks', active.toString(), Icons.bolt_rounded),
            _MetricData(
              'Blocked',
              blocked.toString(),
              Icons.report_problem_rounded,
            ),
            _MetricData(
              'Shipments',
              shipments.toString(),
              Icons.local_shipping_rounded,
            ),
            _MetricData(
              'Reports',
              compliance.toString(),
              Icons.fact_check_rounded,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Today focus', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final record in nextRecords)
          _RecordCard(
            record: record,
            onTap: () => _openRecord(context, record.id),
          ),
      ],
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth >= 560 ? 12.0 : 10.0;
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          metric.icon,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metric.value,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                metric.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class RecordListScreen extends StatelessWidget {
  const RecordListScreen({required this.type, super.key});

  final String type;

  @override
  Widget build(BuildContext context) {
    final store = OpsScope.of(context);
    final records = store.byType(type);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Text(
          RecordType.plural(type),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          _sectionIntro(type),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 14),
        if (records.isEmpty)
          _EmptyPanel(type: type)
        else
          for (final record in records)
            _RecordCard(
              record: record,
              onTap: () => _openRecord(context, record.id),
            ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});

  final OpsRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      RecordType.icon(record.type),
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${record.site} - ${record.owner}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusPill(status: record.status),
                  _InfoPill(icon: Icons.flag_rounded, label: record.priority),
                  _InfoPill(
                    icon: Icons.event_rounded,
                    label: _formatDate(record.dueDate),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              RecordType.icon(type),
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text('No ${RecordType.plural(type).toLowerCase()} yet'),
            const SizedBox(height: 4),
            const Text(
              'Use New to add the first local record.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = OpsScope.of(context);
    final reports = store.byType(RecordType.compliance);
    final openReports = reports
        .where((record) => record.status != RecordStatus.closed)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Text(
          'Compliance and settings',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$openReports open compliance items',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Prepare audits, incident logs, and corrective actions.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final record in reports)
          _RecordCard(
            record: record,
            onTap: () => _openRecord(context, record.id),
          ),
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.storage_rounded,
          title: 'Local storage only',
          subtitle: 'Records stay on this Android device and are not synced.',
        ),
        _SettingsTile(
          icon: Icons.person_outline_rounded,
          title: appName,
          subtitle:
              'Operations workspace for daily facility and logistics tasks.',
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy',
          subtitle:
              'No account, analytics, location, contacts, or advertising identifiers.',
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class RecordDetailPage extends StatelessWidget {
  const RecordDetailPage({required this.recordId, super.key});

  final String recordId;

  @override
  Widget build(BuildContext context) {
    final store = OpsScope.of(context);
    final record = store.findById(recordId);
    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record')),
        body: const Center(child: Text('This record is no longer available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(RecordType.label(record.type)),
        actions: [
          IconButton(
            tooltip: 'Delete',
            onPressed: () async {
              await store.removeRecord(record.id);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(record.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(status: record.status),
              _InfoPill(icon: Icons.business_rounded, label: record.site),
              _InfoPill(icon: Icons.person_rounded, label: record.owner),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operational notes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(record.notes),
                  const Divider(height: 26),
                  _DetailRow(label: 'Priority', value: record.priority),
                  _DetailRow(
                    label: 'Due date',
                    value: _formatLongDate(record.dueDate),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Update status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final status in RecordStatus.values)
                ChoiceChip(
                  label: Text(status),
                  selected: record.status == status,
                  onSelected: (_) =>
                      store.updateRecord(record.copyWith(status: status)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class RecordFormPage extends StatefulWidget {
  const RecordFormPage({required this.initialType, super.key});

  final String initialType;

  @override
  State<RecordFormPage> createState() => _RecordFormPageState();
}

class _RecordFormPageState extends State<RecordFormPage> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  String _status = RecordStatus.queued;
  String _priority = 'Medium';
  late final TextEditingController _titleController;
  late final TextEditingController _ownerController;
  late final TextEditingController _siteController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _titleController = TextEditingController();
    _ownerController = TextEditingController(text: 'Operations desk');
    _siteController = TextEditingController(
      text: _defaultSite(widget.initialType),
    );
    _notesController = TextEditingController(
      text: _defaultNotes(widget.initialType),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ownerController.dispose();
    _siteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New ${RecordType.label(_type).toLowerCase()}'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            key: const ValueKey('saveRecordButton'),
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save record'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Record type'),
              items: [
                for (final type in RecordType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(RecordType.label(type)),
                  ),
              ],
              onChanged: (value) => setState(() {
                _type = value ?? _type;
                _siteController.text = _defaultSite(_type);
                _notesController.text = _defaultNotes(_type);
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('titleField'),
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Add a clear title';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ownerController,
              decoration: const InputDecoration(labelText: 'Owner'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _siteController,
              decoration: const InputDecoration(labelText: 'Site or route'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem(value: 'Low', child: Text('Low')),
                DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                DropdownMenuItem(value: 'High', child: Text('High')),
                DropdownMenuItem(value: 'Critical', child: Text('Critical')),
              ],
              onChanged: (value) =>
                  setState(() => _priority = value ?? _priority),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final status in RecordStatus.values)
                  DropdownMenuItem(value: status, child: Text(status)),
              ],
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              minLines: 4,
              maxLines: 6,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final store = OpsScope.of(context);
    final now = DateTime.now();
    final record = OpsRecord(
      id: now.microsecondsSinceEpoch.toString(),
      type: _type,
      title: _titleController.text.trim(),
      owner: _ownerController.text.trim().isEmpty
          ? 'Operations desk'
          : _ownerController.text.trim(),
      site: _siteController.text.trim().isEmpty
          ? 'Main site'
          : _siteController.text.trim(),
      status: _status,
      priority: _priority,
      dueDate: DateTime(now.year, now.month, now.day + 3),
      notes: _notesController.text.trim().isEmpty
          ? 'Record created for local follow-up.'
          : _notesController.text.trim(),
    );
    await store.addRecord(record);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

void _openRecord(BuildContext context, String id) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => RecordDetailPage(recordId: id),
    ),
  );
}

String _sectionIntro(String type) {
  return switch (type) {
    RecordType.work => 'Assign tasks, track blockers, and close facility work.',
    RecordType.facility =>
      'Coordinate room usage, inspections, and access timing.',
    RecordType.shipment =>
      'Log inbound and outbound movement with clear ownership.',
    RecordType.compliance =>
      'Prepare reporting items and corrective follow-up.',
    _ => 'Track local operations records.',
  };
}

String _defaultSite(String type) {
  return switch (type) {
    RecordType.facility => 'Conference suite A',
    RecordType.shipment => 'Loading bay 2',
    RecordType.compliance => 'Main office',
    _ => 'Facility floor 1',
  };
}

String _defaultNotes(String type) {
  return switch (type) {
    RecordType.facility => 'Confirm access, setup, and cleaning window.',
    RecordType.shipment =>
      'Record carrier, handoff time, and receiving condition.',
    RecordType.compliance =>
      'Attach observations and required follow-up actions.',
    _ => 'Assign owner, parts, and service window before starting.',
  };
}

Color _statusColor(String status) {
  return switch (status) {
    RecordStatus.closed => const Color(0xFF2E7D32),
    RecordStatus.blocked => const Color(0xFFB3261E),
    RecordStatus.inProgress => const Color(0xFF1E5EA8),
    RecordStatus.scheduled => const Color(0xFF6D5E00),
    _ => const Color(0xFF244E5F),
  };
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String _formatLongDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

List<OpsRecord> _starterRecords() {
  return [
    OpsRecord(
      id: 'wo-1001',
      type: RecordType.work,
      title: 'Replace air handler filters',
      owner: 'Facility lead',
      site: 'North wing',
      status: RecordStatus.inProgress,
      priority: 'High',
      dueDate: DateTime(2026, 5, 14),
      notes:
          'Maintenance window before tenant arrival. Confirm filter stock and close with photo notes.',
    ),
    OpsRecord(
      id: 'fb-2107',
      type: RecordType.facility,
      title: 'Reserve training room',
      owner: 'Front office',
      site: 'Conference suite A',
      status: RecordStatus.scheduled,
      priority: 'Medium',
      dueDate: DateTime(2026, 5, 15),
      notes:
          'Prepare seating for twelve, projector check, and access badge list by 09:00.',
    ),
    OpsRecord(
      id: 'sh-7781',
      type: RecordType.shipment,
      title: 'Outbound parts pallet',
      owner: 'Logistics desk',
      site: 'Dock route FR-04',
      status: RecordStatus.queued,
      priority: 'High',
      dueDate: DateTime(2026, 5, 12),
      notes:
          'Verify package count, record carrier seal, and notify recipient at pickup.',
    ),
    OpsRecord(
      id: 'cr-4110',
      type: RecordType.compliance,
      title: 'Monthly safety walk',
      owner: 'Compliance owner',
      site: 'Warehouse aisle C',
      status: RecordStatus.blocked,
      priority: 'Critical',
      dueDate: DateTime(2026, 5, 16),
      notes:
          'Blocked by missing signage. Assign corrective action and document replacement date.',
    ),
    OpsRecord(
      id: 'wo-1002',
      type: RecordType.work,
      title: 'Inspect loading bay door',
      owner: 'Maintenance desk',
      site: 'Loading bay 2',
      status: RecordStatus.scheduled,
      priority: 'Medium',
      dueDate: DateTime(2026, 5, 17),
      notes:
          'Check sensor alignment and log open-close cycle before peak dispatch.',
    ),
    OpsRecord(
      id: 'sh-7782',
      type: RecordType.shipment,
      title: 'Inbound office equipment',
      owner: 'Receiving team',
      site: 'Main reception',
      status: RecordStatus.closed,
      priority: 'Low',
      dueDate: DateTime(2026, 5, 11),
      notes: 'Received complete. Archive delivery note with local record.',
    ),
  ];
}
