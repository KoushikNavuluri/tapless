import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ink = Color(0xff011a51);
const pink = Color(0xffff0066);
const paper = Color(0xfffffafd);
const green = Color(0xff2a9d3d);
const amber = Color(0xffdb7003);
const bronze = Color(0xff9a6b3f);
const muted = Color(0xff655d74);

const storageKey = 'tapless.v1';

const permissionLabels = <String, String>{
  'location': 'Location, all the time',
  'alarms': 'Alarms & reminders',
  'notifications': 'Notification access',
};

const permissionHelp = <String, String>{
  'location': 'Needed for arrive and leave triggers.',
  'alarms': 'Needed for exact time triggers.',
  'notifications': 'Needed for OTP and bank SMS triggers.',
};

Map<String, bool> defaultPermissions() => <String, bool>{
      'location': false,
      'alarms': false,
      'notifications': true,
    };

void main() => runApp(const TaplessApp());

class TaplessApp extends StatelessWidget {
  const TaplessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tapless',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(seedColor: pink),
      ),
      home: const TaplessHome(),
    );
  }
}

class TaplessHome extends StatefulWidget {
  const TaplessHome({super.key});

  @override
  State<TaplessHome> createState() => _TaplessHomeState();
}

class _TaplessHomeState extends State<TaplessHome> {
  int tab = 0;
  bool loading = true;
  final automations = <Automation>[];
  final runs = <RunLog>[];
  final permissions = defaultPermissions();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final savedAutomations = data['automations'] as List? ?? const <dynamic>[];
        final savedRuns = data['runs'] as List? ?? const <dynamic>[];
        final savedPermissions = data['permissions'] as Map? ?? const <String, dynamic>{};
        automations.addAll(
          savedAutomations.map((item) => Automation.fromJson(item as Map)),
        );
        runs.addAll(savedRuns.map((item) => RunLog.fromJson(item as Map)));
        permissions.addAll(Map<String, bool>.from(savedPermissions));
      }
    } catch (_) {
      // Storage is unavailable or malformed. Start from the sample data.
      automations.clear();
      runs.clear();
    }
    if (automations.isEmpty) {
      automations.addAll(Automation.seed());
    }
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        storageKey,
        jsonEncode({
          'automations': automations.map((item) => item.toJson()).toList(),
          'runs': runs.map((item) => item.toJson()).toList(),
          'permissions': permissions,
        }),
      );
    } catch (_) {
      // Saving is best effort. The in-memory state keeps working.
    }
  }

  void _toast(String message, {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), action: action));
  }

  bool _isMissingAccess(Automation automation) {
    final needs = automation.needs;
    return needs != null && permissions[needs] != true;
  }

  RunLog _evaluate(Automation automation, String event) {
    if (!automation.enabled) {
      return RunLog(automation.name, 'skipped', '$event → line is paused, nothing ran', DateTime.now());
    }
    if (_isMissingAccess(automation)) {
      final label = permissionLabels[automation.needs] ?? automation.needs;
      return RunLog(automation.name, 'blocked', '$event → needs $label first', DateTime.now());
    }
    return RunLog(automation.name, 'ran', '$event → ${automation.actions.join(' → ')}', DateTime.now());
  }

  RunLog _record(Automation automation, String event) {
    final run = _evaluate(automation, event);
    setState(() {
      runs.insert(0, run);
      if (runs.length > 50) {
        runs.removeRange(50, runs.length);
      }
    });
    _save();
    return run;
  }

  void _run(Automation automation, {String event = 'Manual test'}) {
    final run = _record(automation, event);
    _toast(
      '${automation.name} ${run.outcome}',
      action: run.outcome == 'blocked'
          ? SnackBarAction(label: 'Fix', onPressed: () => setState(() => tab = 3))
          : null,
    );
  }

  void _simulate(SimEvent event) {
    final matches = automations
        .where((automation) => automation.trigger.toLowerCase().contains(event.match))
        .toList();
    if (matches.isEmpty) {
      _toast('Nothing listens for "${event.label}" yet');
      return;
    }
    for (final automation in matches) {
      _record(automation, event.label);
    }
    final names = matches.map((automation) => automation.name).join(', ');
    _toast('${event.label} → $names. See Runs.');
  }

  void _toggle(Automation automation, bool enabled) {
    setState(() => automation.enabled = enabled);
    _save();
  }

  void _add(Automation automation) {
    setState(() {
      automations.insert(0, automation);
      tab = 0;
    });
    _save();
    _toast('${automation.name} saved and armed');
  }

  void _delete(Automation automation) {
    setState(() => automations.remove(automation));
    _save();
    _toast('${automation.name} deleted');
  }

  void _grant(String key) {
    setState(() => permissions[key] = true);
    _save();
    _toast('${permissionLabels[key] ?? key} granted (simulated)');
  }

  void _share(Automation automation) {
    final text = 'Tapless recipe: ${automation.name}\n'
        '${automation.summary}\n'
        'https://tapless.example/r/${slug(automation.name)}';
    Clipboard.setData(ClipboardData(text: text));
    _toast('Recipe copied. Paste it anywhere to share.');
  }

  void _clearRuns() {
    setState(runs.clear);
    _save();
  }

  Future<void> _reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {
      // Reset the in-memory state even if storage fails.
    }
    if (!mounted) return;
    setState(() {
      automations
        ..clear()
        ..addAll(Automation.seed());
      runs.clear();
      permissions
        ..clear()
        ..addAll(defaultPermissions());
      tab = 0;
    });
    _toast('Demo reset');
  }

  void _openBuilder() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BuilderSheet(onSave: _add),
    );
  }

  void _openDetail(Automation automation) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DetailSheet(
        automation: automation,
        missingAccess: _isMissingAccess(automation),
        onRun: () {
          Navigator.pop(sheetContext);
          _run(automation);
        },
        onShare: () {
          Navigator.pop(sheetContext);
          _share(automation);
        },
        onDelete: () {
          Navigator.pop(sheetContext);
          _delete(automation);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: [
            HomePage(
              automations: automations,
              isMissingAccess: _isMissingAccess,
              onBuild: _openBuilder,
              onRun: _run,
              onOpen: _openDetail,
              onToggle: _toggle,
              onSimulate: _simulate,
            ),
            GalleryPage(onAdd: _add),
            RunsPage(runs: runs, onClear: _clearRuns),
            DoctorPage(permissions: permissions, onGrant: _grant),
            SettingsPage(onReset: _reset),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Gallery',
          ),
          NavigationDestination(
            icon: Icon(Icons.train_outlined),
            selectedIcon: Icon(Icons.train),
            label: 'Runs',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'Doctor',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

String slug(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

String clock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

Color outcomeColor(String outcome) {
  if (outcome == 'ran') return green;
  if (outcome == 'blocked') return amber;
  return bronze;
}

const headline = TextStyle(
  fontSize: 32,
  height: 1.05,
  fontWeight: FontWeight.w900,
  letterSpacing: -1.2,
  color: ink,
);

const mono = TextStyle(fontSize: 11, letterSpacing: 1.2, color: muted);

Widget badge(
  String text, {
  Color color = ink,
  Color background = const Color(0xfff2e9ee),
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

Widget station(IconData icon, Color color) {
  return Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    child: Icon(icon, size: 13, color: Colors.white),
  );
}

class Automation {
  String name;
  String trigger;
  List<String> conditions;
  List<String> actions;
  bool enabled;
  String? needs;

  Automation(
    this.name,
    this.trigger,
    this.conditions,
    this.actions, {
    this.enabled = true,
    this.needs,
  });

  String get summary {
    final rest = conditions.isEmpty ? '' : ', only if ${conditions.join(' and ')}';
    return 'When ${trigger.toLowerCase()}$rest: ${actions.join(', then ')}.';
  }

  Automation copy() => Automation(
        name,
        trigger,
        List<String>.of(conditions),
        List<String>.of(actions),
        enabled: enabled,
        needs: needs,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'trigger': trigger,
        'conditions': conditions,
        'actions': actions,
        'enabled': enabled,
        'needs': needs,
      };

  factory Automation.fromJson(Map value) {
    return Automation(
      value['name'] as String? ?? 'Untitled',
      value['trigger'] as String? ?? 'When you tap it',
      List<String>.from(value['conditions'] as List? ?? const <String>[]),
      List<String>.from(value['actions'] as List? ?? const <String>[]),
      enabled: value['enabled'] as bool? ?? true,
      needs: value['needs'] as String?,
    );
  }

  static List<Automation> seed() => [
        Automation(
          'Car mode',
          'Swift car connects',
          ['Bluetooth is on'],
          ['Open Google Maps', 'Play Telugu Drive', 'Set volume to 70%'],
        ),
        Automation(
          'Bedtime',
          'You plug in',
          ['Between 10:30 PM and 6:00 AM'],
          ['Do Not Disturb priority', 'Brightness 15%'],
        ),
        Automation(
          'Morning brief',
          'Weekdays at 7:00 AM',
          <String>[],
          ['Say today’s meetings', 'Show summary'],
          needs: 'alarms',
        ),
      ];
}

class RunLog {
  final String name;
  final String outcome;
  final String detail;
  final DateTime at;

  RunLog(this.name, this.outcome, this.detail, this.at);

  Map<String, dynamic> toJson() => {
        'name': name,
        'outcome': outcome,
        'detail': detail,
        'at': at.toIso8601String(),
      };

  factory RunLog.fromJson(Map value) {
    return RunLog(
      value['name'] as String? ?? 'Unknown',
      value['outcome'] as String? ?? 'ran',
      value['detail'] as String? ?? '',
      DateTime.tryParse(value['at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class SimEvent {
  final String label;
  final String match;

  const SimEvent(this.label, this.match);
}

const simEvents = <SimEvent>[
  SimEvent('Car connects', 'car connects'),
  SimEvent('Phone plugged in', 'plug in'),
  SimEvent('7:00 AM weekday', '7:00 am'),
  SimEvent('Arrive at gym', 'arrive'),
  SimEvent('OTP SMS arrives', 'sms'),
];

const actionWords = <List<String>>[
  ['silen', 'Set ringer silent'],
  ['quiet', 'Set ringer silent'],
  ['mute', 'Set ringer silent'],
  ['dnd', 'Do Not Disturb priority'],
  ['disturb', 'Do Not Disturb priority'],
  ['map', 'Open Google Maps'],
  ['music', 'Play Liked Songs'],
  ['play', 'Play Liked Songs'],
  ['wifi', 'Turn Wi-Fi on'],
  ['wi-fi', 'Turn Wi-Fi on'],
  ['bright', 'Brightness 15%'],
  ['torch', 'Torch on'],
  ['flashlight', 'Torch on'],
  ['copy', 'Copy the code'],
];

Automation gymTemplate() => Automation(
      'Gym mode',
      'Arrive at the gym',
      ['Between 5:30 AM and 10:00 AM', 'Mon to Sat'],
      ['Do Not Disturb priority', 'Play a playlist', 'Quiet notification'],
      needs: 'location',
    );

Automation compileText(String input) {
  final text = input.toLowerCase();
  var name = 'Quick rule';
  var trigger = 'When you tap it';
  String? needs;
  if (text.contains('plug') || text.contains('charg')) {
    name = 'Charging rule';
    trigger = 'You plug in';
  } else if (text.contains('car') || text.contains('bluetooth')) {
    name = 'Car rule';
    trigger = 'Your car connects';
  } else if (text.contains('morning') || text.contains('wake') || text.contains('alarm')) {
    name = 'Morning rule';
    trigger = 'Weekdays at 7:00 AM';
    needs = 'alarms';
  } else if (text.contains('otp') || text.contains('sms')) {
    name = 'SMS rule';
    trigger = 'An SMS arrives';
    needs = 'notifications';
  }

  final actions = <String>[];
  for (final pair in actionWords) {
    if (text.contains(pair[0]) && !actions.contains(pair[1])) {
      actions.add(pair[1]);
    }
  }
  if (actions.isEmpty) {
    actions.add('Show a notification');
  }
  return Automation(name, trigger, <String>[], actions, needs: needs);
}

class HomePage extends StatelessWidget {
  final List<Automation> automations;
  final bool Function(Automation) isMissingAccess;
  final VoidCallback onBuild;
  final void Function(Automation) onRun;
  final void Function(Automation) onOpen;
  final void Function(Automation, bool) onToggle;
  final void Function(SimEvent) onSimulate;

  const HomePage({
    super.key,
    required this.automations,
    required this.isMissingAccess,
    required this.onBuild,
    required this.onRun,
    required this.onOpen,
    required this.onToggle,
    required this.onSimulate,
  });

  @override
  Widget build(BuildContext context) {
    final armed = automations.where((automation) => automation.enabled).length;
    final cards = automations
        .map(
          (automation) => AutomationCard(
            automation: automation,
            missingAccess: isMissingAccess(automation),
            onRun: () => onRun(automation),
            onOpen: () => onOpen(automation),
            onToggle: (enabled) => onToggle(automation, enabled),
          ),
        )
        .toList();
    final eventChips = simEvents
        .map(
          (event) => ActionChip(
            avatar: const Icon(Icons.bolt, size: 18),
            label: Text(event.label),
            onPressed: () => onSimulate(event),
          ),
        )
        .toList();

    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Row(
          children: [
            const Text(
              'TAPLESS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ink),
            ),
            const Spacer(),
            badge('LISTENING', color: green, background: const Color(0xffe3f3e5)),
          ],
        ),
        const SizedBox(height: 28),
        const Text('Your phone,\non autopilot.', style: headline),
        const SizedBox(height: 12),
        const Text(
          'Every rule is a line. Every run, a train.',
          style: TextStyle(fontSize: 17, color: Color(0xff3a4669)),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onBuild,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Build an automation'),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Text('AUTOMATIONS', style: mono),
            const Spacer(),
            Text('$armed armed', style: mono),
          ],
        ),
        const SizedBox(height: 10),
        if (cards.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No lines yet. Build one or steal one from Gallery.',
              style: TextStyle(color: muted),
            ),
          ),
        ...cards,
        const SizedBox(height: 20),
        const Text('SIMULATE AN EVENT', style: mono),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: eventChips),
        const SizedBox(height: 16),
        const Text(
          'AI, Android permission screens and integrations are simulated in this build.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }
}

class AutomationCard extends StatelessWidget {
  final Automation automation;
  final bool missingAccess;
  final VoidCallback onRun;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;

  const AutomationCard({
    super.key,
    required this.automation,
    required this.missingAccess,
    required this.onRun,
    required this.onOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final lineColor = !automation.enabled ? muted : (missingAccess ? amber : green);
    final stations = automation.actions.take(3).map((_) => station(Icons.circle, ink)).toList();
    final chips = <Widget>[badge('WHEN')];
    if (missingAccess) {
      chips.add(badge('NEEDS ACCESS', color: amber, background: const Color(0xfffff0dc)));
    }
    chips.addAll(
      automation.conditions.map(
        (item) => badge(item, color: amber, background: const Color(0xfffff0dc)),
      ),
    );
    chips.addAll(
      automation.actions.take(2).map(
            (item) => badge(item, background: const Color(0xffeef1fa)),
          ),
    );

    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      automation.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                  Switch(value: automation.enabled, onChanged: onToggle),
                ],
              ),
              Text(automation.trigger, style: const TextStyle(color: muted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  station(Icons.bolt, pink),
                  Expanded(child: Container(height: 4, color: lineColor)),
                  ...stations,
                ],
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: chips),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRun,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Test run'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BuilderSheet extends StatefulWidget {
  final void Function(Automation) onSave;

  const BuilderSheet({super.key, required this.onSave});

  @override
  State<BuilderSheet> createState() => _BuilderSheetState();
}

class _BuilderSheetState extends State<BuilderSheet> {
  static const examples = <String>[
    'At the gym, silence my phone',
    'When I plug in, turn on DND',
    'When my car connects, open maps',
  ];
  static const gyms = <String>['Cult.fit Kondapur', 'Gold’s Gym Jubilee Hills'];
  static const playlists = <String>['Gym Bangers', 'Telugu Drive', 'Liked Songs'];

  final controller = TextEditingController();
  String? status;
  Automation? draft;
  bool needsSlots = false;
  String? place;
  String? playlist;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void compile() {
    final text = controller.text.trim().toLowerCase();
    setState(() {
      if (text.isEmpty) {
        status = 'Type what your phone should do first.';
        draft = null;
        needsSlots = false;
      } else if (text.contains('gym')) {
        status = 'Recipe matched · no AI call';
        draft = gymTemplate();
        needsSlots = true;
      } else {
        status = 'Compiled on device · AI simulated';
        draft = compileText(text);
        needsSlots = false;
      }
    });
  }

  void useExample(String example) {
    controller.text = example;
    compile();
  }

  Automation preview(Automation current) {
    if (!needsSlots) return current;
    return Automation(
      current.name,
      'Arrive at ${place ?? 'which gym?'}',
      current.conditions,
      [
        'Do Not Disturb priority',
        'Play ${playlist ?? 'which playlist?'}',
        'Quiet notification',
      ],
      needs: current.needs,
    );
  }

  void _commit(Automation automation) {
    widget.onSave(automation);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final current = draft;
    final exampleChips = examples
        .map(
          (example) => ActionChip(
            label: Text(example),
            onPressed: () => useExample(example),
          ),
        )
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              const Text('Say it like you’d text a friend.', style: headline),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'When I get to the gym, silence my phone…',
                  filled: true,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: exampleChips),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: compile,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Build'),
              ),
              if (status != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(status!, style: mono),
                ),
              if (current != null) _draftCard(preview(current)),
            ],
          );
        },
      ),
    );
  }

  Widget _draftCard(Automation shown) {
    final ready = !needsSlots || (place != null && playlist != null);
    final gymChips = gyms
        .map(
          (item) => ChoiceChip(
            label: Text(item),
            selected: place == item,
            onSelected: (_) => setState(() => place = item),
          ),
        )
        .toList();
    final playlistChips = playlists
        .map(
          (item) => ChoiceChip(
            label: Text(item),
            selected: playlist == item,
            onSelected: (_) => setState(() => playlist = item),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shown.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink),
                ),
                const SizedBox(height: 12),
                Text(
                  'WHEN  ${shown.trigger}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                ...shown.conditions.map((item) => Text('ONLY IF  $item')),
                const Divider(),
                const Text('DO', style: mono),
                ...shown.actions.map((item) => Text('●  $item')),
                if (shown.needs != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Needs ${permissionLabels[shown.needs] ?? shown.needs}',
                    style: const TextStyle(color: amber, fontWeight: FontWeight.w700),
                  ),
                ],
                if (needsSlots) ...[
                  const SizedBox(height: 12),
                  const Text('Which gym?'),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: gymChips),
                  const SizedBox(height: 12),
                  const Text('Which playlist?'),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: playlistChips),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: ready ? () => _commit(shown) : null,
          child: Text(ready ? 'Save to Tapless' : 'Pick a gym and playlist'),
        ),
      ],
    );
  }
}

class DetailSheet extends StatelessWidget {
  final Automation automation;
  final bool missingAccess;
  final VoidCallback onRun;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const DetailSheet({
    super.key,
    required this.automation,
    required this.missingAccess,
    required this.onRun,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final label = permissionLabels[automation.needs] ?? automation.needs;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Text(automation.name, style: headline),
            const SizedBox(height: 8),
            Text(automation.summary, style: const TextStyle(fontSize: 16, color: muted)),
            if (missingAccess)
              Card(
                color: const Color(0xfffff0dc),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber, color: amber),
                  title: Text('Needs $label'),
                  subtitle: const Text('Grant it in the Doctor tab, then run again.'),
                ),
              ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.bolt, color: pink),
              title: Text(automation.trigger),
              subtitle: const Text('Trigger'),
            ),
            ...automation.conditions.map(
              (item) => ListTile(
                leading: const Icon(Icons.crop_square, color: amber),
                title: Text(item),
                subtitle: const Text('Only if'),
              ),
            ),
            ...automation.actions.map(
              (item) => ListTile(
                leading: const Icon(Icons.circle, size: 14, color: ink),
                title: Text(item),
                subtitle: const Text('Do'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRun,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Test run'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.copy),
              label: const Text('Copy recipe'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

class Recipe {
  final String blurb;
  final Automation automation;

  const Recipe(this.blurb, this.automation);
}

List<Recipe> buildRecipes() => [
      Recipe(
        'Silent at the gym, playlist on.',
        Automation(
          'Gym mode',
          'Arrive at Cult.fit Kondapur',
          ['Between 5:30 AM and 10:00 AM'],
          ['Do Not Disturb priority', 'Play Gym Bangers'],
          needs: 'location',
        ),
      ),
      Recipe(
        'An OTP lands and the code is already copied.',
        Automation(
          'OTP to clipboard',
          'An SMS with an OTP arrives',
          <String>[],
          ['Copy the code', 'Show a quiet notification'],
          needs: 'notifications',
        ),
      ),
      Recipe(
        'Every debited SMS becomes a row in your expense sheet.',
        Automation(
          'UPI expense log',
          'A bank SMS says debited',
          <String>[],
          ['Read amount and merchant', 'Add a row to Expenses'],
          needs: 'notifications',
        ),
      ),
      Recipe(
        'Plug in at night and your phone goes quiet.',
        Automation(
          'Bedtime',
          'You plug in',
          ['Between 10:30 PM and 6:00 AM'],
          ['Do Not Disturb priority', 'Brightness 15%'],
        ),
      ),
      Recipe(
        'Low battery? Dim the screen and save power.',
        Automation(
          'Battery saver',
          'Battery drops below 20%',
          <String>[],
          ['Battery saver on', 'Brightness 30%'],
        ),
      ),
    ];

class GalleryPage extends StatelessWidget {
  final void Function(Automation) onAdd;

  const GalleryPage({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final recipes = buildRecipes();

    return ListView(
      primary: false,
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Steal good ideas.', style: headline),
        const SizedBox(height: 8),
        Text('RECIPES · ${recipes.length}', style: mono),
        const SizedBox(height: 14),
        ...recipes.map(
          (recipe) => Card(
            child: ListTile(
              title: Text(
                recipe.automation.name,
                style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
              ),
              subtitle: Text(recipe.blurb),
              trailing: IconButton(
                tooltip: 'Add to Tapless',
                onPressed: () => onAdd(recipe.automation.copy()),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class RunsPage extends StatelessWidget {
  final List<RunLog> runs;
  final VoidCallback onClear;

  const RunsPage({super.key, required this.runs, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return ListView(
      primary: false,
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(child: Text('Every run,\nexplained.', style: headline)),
            if (runs.isNotEmpty) TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: 16),
        if (runs.isEmpty)
          const Text(
            'No runs yet. Test a line or simulate an event on Home.',
            style: TextStyle(color: muted),
          ),
        ...runs.map(
          (run) => Card(
            child: ListTile(
              leading: Icon(Icons.circle, size: 12, color: outcomeColor(run.outcome)),
              title: Text(run.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${clock(run.at)} · ${run.detail}'),
              trailing: badge(run.outcome.toUpperCase(), color: outcomeColor(run.outcome)),
            ),
          ),
        ),
      ],
    );
  }
}

class DoctorPage extends StatelessWidget {
  final Map<String, bool> permissions;
  final void Function(String) onGrant;

  const DoctorPage({super.key, required this.permissions, required this.onGrant});

  @override
  Widget build(BuildContext context) {
    final granted = permissions.values.where((value) => value).length;
    final score = permissions.isEmpty ? 100 : (granted / permissions.length * 100).round();

    return ListView(
      primary: false,
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Keep it alive.', style: headline),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$score/100',
                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: ink),
                ),
                const Text('Reliability score', style: mono),
              ],
            ),
          ),
        ),
        ...permissions.entries.map(
          (entry) => Card(
            child: ListTile(
              leading: Icon(
                entry.value ? Icons.check_circle : Icons.warning_amber,
                color: entry.value ? green : amber,
              ),
              title: Text(permissionLabels[entry.key] ?? entry.key),
              subtitle: Text(
                entry.value ? 'Granted' : (permissionHelp[entry.key] ?? 'Missing access'),
              ),
              trailing: entry.value
                  ? null
                  : TextButton(
                      onPressed: () => onGrant(entry.key),
                      child: const Text('Grant'),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Grant buttons are simulated. Real Android permission prompts land in the native milestone.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  final VoidCallback onReset;

  const SettingsPage({super.key, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return ListView(
      primary: false,
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Settings', style: headline),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.smartphone),
            title: Text('Redmi Note 13 Pro'),
            subtitle: Text('HyperOS 2 · Android 15'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Runs on device'),
            subtitle: Text('Rules run locally. AI only helps write them.'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About this build'),
            subtitle: Text('Tapless 0.1.1. AI, Android screens and integrations are simulated.'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset demo'),
            subtitle: const Text('Restore the sample lines and clear runs.'),
            onTap: onReset,
          ),
        ),
      ],
    );
  }
}
