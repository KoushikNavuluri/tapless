import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ink = Color(0xff011a51);
const pink = Color(0xffff0066);
const paper = Color(0xfffffafd);
const green = Color(0xff2a9d3d);
const amber = Color(0xffdb7003);
const muted = Color(0xff655d74);

void main() => runApp(const TaplessApp());

class TaplessApp extends StatefulWidget {
  const TaplessApp({super.key});

  @override
  State<TaplessApp> createState() => _TaplessAppState();
}

class _TaplessAppState extends State<TaplessApp> {
  int tab = 0;
  bool loading = true;
  final automations = <Automation>[];
  final runs = <RunLog>[];
  final permissions = <String, bool>{
    'location': false,
    'alarms': false,
    'notifications': true,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tapless.v1');
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        automations.addAll(
          (data['automations'] as List? ?? [])
              .map((item) => Automation.fromJson(item as Map)),
        );
        runs.addAll(
          (data['runs'] as List? ?? [])
              .map((item) => RunLog.fromJson(item as Map)),
        );
        permissions.addAll(
          Map<String, bool>.from(data['permissions'] as Map? ?? {}),
        );
      } catch (_) {
        // Start with the seed data when local data is malformed.
      }
    }
    if (automations.isEmpty) {
      automations.addAll(Automation.seed());
    }
    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'tapless.v1',
      jsonEncode({
        'automations': automations.map((item) => item.toJson()).toList(),
        'runs': runs.map((item) => item.toJson()).toList(),
        'permissions': permissions,
      }),
    );
  }

  void _run(Automation automation, {String event = 'Manual tap'}) {
    final outcome = automation.enabled ? 'ran' : 'blocked';
    final detail = '$event → ${automation.actions.join(' → ')}';
    final run = RunLog(automation.name, outcome, detail);
    setState(() => runs.insert(0, run));
    _save();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${automation.name} $outcome')),
    );
  }

  void _buildAutomation() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BuilderSheet(
        onSave: (automation) {
          setState(() => automations.insert(0, automation));
          _save();
        },
      ),
    );
  }

  void _openDetail(Automation automation) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DetailSheet(
        automation: automation,
        onRun: () => _run(automation),
        onShare: () => Share.share(
          'Tapless recipe: ${automation.name}\n'
          'https://tapless.example/r/${slug(automation.name)}',
        ),
      ),
    );
  }

  Future<void> _reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tapless.v1');
    setState(() {
      automations
        ..clear()
        ..addAll(Automation.seed());
      runs.clear();
      permissions
        ..clear()
        ..addAll({
          'location': false,
          'alarms': false,
          'notifications': true,
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(seedColor: pink),
      ),
      home: Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: tab,
            children: [
              HomePage(
                automations: automations,
                onBuild: _buildAutomation,
                onRun: _run,
                onOpen: _openDetail,
              ),
              const GalleryPage(),
              RunsPage(runs: runs),
              DoctorPage(
                permissions: permissions,
                onGrant: (key) {
                  setState(() => permissions[key] = true);
                  _save();
                },
              ),
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
      ),
    );
  }
}

String slug(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

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

class Automation {
  String name;
  String trigger;
  List<String> conditions;
  List<String> actions;
  bool enabled;

  Automation(
    this.name,
    this.trigger,
    this.conditions,
    this.actions, {
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'trigger': trigger,
        'conditions': conditions,
        'actions': actions,
        'enabled': enabled,
      };

  factory Automation.fromJson(Map value) {
    return Automation(
      value['name'] as String,
      value['trigger'] as String,
      List<String>.from(value['conditions'] ?? <String>[]),
      List<String>.from(value['actions'] ?? <String>[]),
      enabled: value['enabled'] as bool? ?? true,
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
          [],
          ['Say today’s meetings', 'Show summary'],
        ),
      ];
}

class RunLog {
  final String name;
  final String outcome;
  final String detail;

  RunLog(this.name, this.outcome, this.detail);

  Map<String, dynamic> toJson() => {
        'name': name,
        'outcome': outcome,
        'detail': detail,
      };

  factory RunLog.fromJson(Map value) {
    return RunLog(
      value['name'] as String,
      value['outcome'] as String,
      value['detail'] as String,
    );
  }
}

class HomePage extends StatelessWidget {
  final List<Automation> automations;
  final VoidCallback onBuild;
  final void Function(Automation) onRun;
  final void Function(Automation) onOpen;

  const HomePage({
    super.key,
    required this.automations,
    required this.onBuild,
    required this.onRun,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cards = automations
        .map(
          (automation) => AutomationCard(
            automation: automation,
            onRun: () => onRun(automation),
            onOpen: () => onOpen(automation),
          ),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Row(
          children: [
            const Text(
              'TAPLESS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
            const Spacer(),
            badge(
              'LISTENING',
              color: green,
              background: const Color(0xffe3f3e5),
            ),
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
            Text('${automations.length} armed', style: mono),
          ],
        ),
        const SizedBox(height: 10),
        ...cards,
        const SizedBox(height: 12),
        const Text(
          'AI and integrations are simulated in this build.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }
}

class AutomationCard extends StatelessWidget {
  final Automation automation;
  final VoidCallback onRun;
  final VoidCallback onOpen;

  const AutomationCard({
    super.key,
    required this.automation,
    required this.onRun,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final stations = automation.actions.take(3).map((_) => station(Icons.circle)).toList();
    final chips = <Widget>[badge('WHEN')];
    chips.addAll(
      automation.conditions.map(
        (item) => badge(
          item,
          color: amber,
          background: const Color(0xfffff0dc),
        ),
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
        borderRadius: BorderRadius.circular(20),
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
                  Switch(value: automation.enabled, onChanged: (_) {}),
                ],
              ),
              Text(automation.trigger, style: const TextStyle(color: muted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  station(Icons.bolt),
                  Expanded(child: Container(height: 4, color: green)),
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

Widget station(IconData icon) {
  return Container(
    width: 24,
    height: 24,
    decoration: const BoxDecoration(shape: BoxShape.circle, color: ink),
    child: Icon(icon, size: 13, color: Colors.white),
  );
}

class BuilderSheet extends StatefulWidget {
  final void Function(Automation) onSave;

  const BuilderSheet({super.key, required this.onSave});

  @override
  State<BuilderSheet> createState() => _BuilderSheetState();
}

class _BuilderSheetState extends State<BuilderSheet> {
  final controller = TextEditingController();
  String? status;
  Automation? draft;
  String? place;
  String? playlist;

  void compile() {
    final text = controller.text.toLowerCase();
    final isGym = text.contains('gym');
    final automation = isGym
        ? Automation(
            'Gym mode',
            'Arrive at a place',
            ['Between 5:30 AM and 10:00 AM', 'Mon to Sat'],
            [
              'Do Not Disturb priority',
              'Play ${playlist ?? '{playlist}'}',
              'Quiet notification',
            ],
          )
        : Automation(
            'My automation',
            'When you tap it',
            [],
            [
              text.contains('silent')
                  ? 'Set ringer silent'
                  : 'Run the requested action',
            ],
          );

    setState(() {
      status = isGym ? 'Recipe matched · no AI call' : 'AI compile (simulated)';
      draft = automation;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .86,
        builder: (_, scrollController) {
          return Material(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
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
                if (draft != null) _draftCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _draftCard() {
    final current = draft!;
    final conditionWidgets = current.conditions.map((item) => Text('ONLY IF  $item')).toList();
    final actionWidgets = current.actions.map((item) => Text('●  $item')).toList();
    final isGym = current.name == 'Gym mode';

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'WHEN  ${current.trigger}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                ...conditionWidgets,
                const Divider(),
                const Text('DO', style: mono),
                ...actionWidgets,
                if (isGym) ...[
                  const SizedBox(height: 12),
                  const Text('Which gym?'),
                  Wrap(
                    spacing: 8,
                    children: [
                      'Cult.fit Kondapur',
                      'Gold’s Gym Jubilee Hills',
                    ].map((item) {
                      return ChoiceChip(
                        label: Text(item),
                        selected: place == item,
                        onSelected: (_) => setState(() => place = item),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  const Text('Which playlist?'),
                  Wrap(
                    spacing: 8,
                    children: ['Gym Bangers', 'Telugu Drive', 'Liked Songs']
                        .map((item) {
                      return ChoiceChip(
                        label: Text(item),
                        selected: playlist == item,
                        onSelected: (_) => setState(() => playlist = item),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: !isGym || (place != null && playlist != null)
              ? () {
                  widget.onSave(current);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Save to Tapless'),
        ),
      ],
    );
  }
}

class DetailSheet extends StatelessWidget {
  final Automation automation;
  final VoidCallback onRun;
  final VoidCallback onShare;

  const DetailSheet({
    super.key,
    required this.automation,
    required this.onRun,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final conditions = automation.conditions
        .map(
          (item) => ListTile(
            leading: const Icon(Icons.crop_square, color: amber),
            title: Text(item),
          ),
        )
        .toList();
    final actions = automation.actions
        .map(
          (item) => ListTile(
            leading: const Icon(Icons.circle, color: ink),
            title: Text(item),
          ),
        )
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      builder: (_, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Text(automation.name, style: headline),
            Text(
              automation.trigger,
              style: const TextStyle(fontSize: 16, color: muted),
            ),
            const SizedBox(height: 20),
            ...conditions,
            ...actions,
            FilledButton.icon(
              onPressed: onRun,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Test run'),
            ),
            OutlinedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share),
              label: const Text('Share recipe'),
            ),
          ],
        );
      },
    );
  }
}

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final recipes = <List<String>>[
      ['Gym mode', 'Silent at the gym, playlist on, back to normal when you leave.'],
      ['OTP to clipboard', 'An OTP lands and the code is already copied.'],
      ['UPI expense log', 'Every debited SMS becomes a row in your expense sheet.'],
      ['Bedtime', 'Plug in at night and your phone goes quiet.'],
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Steal good ideas.', style: headline),
        const SizedBox(height: 8),
        const Text('RECIPES · 12', style: mono),
        const SizedBox(height: 14),
        ...recipes.map(
          (recipe) => Card(
            child: ListTile(
              title: Text(
                recipe[0],
                style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
              ),
              subtitle: Text(recipe[1]),
              trailing: const Icon(Icons.arrow_forward_ios, size: 15),
            ),
          ),
        ),
      ],
    );
  }
}

class RunsPage extends StatelessWidget {
  final List<RunLog> runs;

  const RunsPage({super.key, required this.runs});

  @override
  Widget build(BuildContext context) {
    final runCards = runs
        .map(
          (run) => Card(
            child: ListTile(
              leading: Icon(
                Icons.circle,
                size: 12,
                color: run.outcome == 'ran' ? green : amber,
              ),
              title: Text(run.name),
              subtitle: Text(run.detail),
              trailing: badge(
                run.outcome.toUpperCase(),
                color: run.outcome == 'ran' ? green : amber,
              ),
            ),
          ),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Every run,\nexplained.', style: headline),
        const SizedBox(height: 16),
        if (runCards.isEmpty) const Text('No runs yet.'),
        ...runCards,
      ],
    );
  }
}

class DoctorPage extends StatelessWidget {
  final Map<String, bool> permissions;
  final void Function(String) onGrant;

  const DoctorPage({
    super.key,
    required this.permissions,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    final granted = permissions.values.where((value) => value).length;
    final score = permissions.isEmpty ? 0 : (granted / permissions.length * 100).round();
    final checks = permissions.entries.map((entry) {
      final isGranted = entry.value;
      return Card(
        child: ListTile(
          leading: Icon(
            isGranted ? Icons.check_circle : Icons.warning,
            color: isGranted ? green : amber,
          ),
          title: Text(entry.key),
          subtitle: Text(isGranted ? 'Granted' : 'Missing access'),
          trailing: isGranted
              ? null
              : TextButton(
                  onPressed: () => onGrant(entry.key),
                  child: const Text('Grant'),
                ),
        ),
      );
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Keep it alive.', style: headline),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '$score/100',
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
          ),
        ),
        ...checks,
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
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Settings', style: headline),
        const Card(
          child: ListTile(
            leading: Icon(Icons.smartphone),
            title: Text('Redmi Note 13 Pro'),
            subtitle: Text('HyperOS 2 · Android 15'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About this build'),
            subtitle: Text('AI, Android screens and integrations are simulated locally.'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset demo'),
            onTap: onReset,
          ),
        ),
      ],
    );
  }
}
