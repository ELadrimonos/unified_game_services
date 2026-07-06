import 'package:flutter/material.dart';
import 'package:unified_game_services/unified_game_services.dart';

import 'app_state.dart';
import 'env.dart';
import 'screens/config_screen.dart';
import 'services/registry.dart';

void main() {
  runApp(const UnifiedDemoApp());
}

class UnifiedDemoApp extends StatefulWidget {
  const UnifiedDemoApp({super.key});

  @override
  State<UnifiedDemoApp> createState() => _UnifiedDemoAppState();
}

class _UnifiedDemoAppState extends State<UnifiedDemoApp> {
  final AppState _app = AppState();

  @override
  void initState() {
    super.initState();
    _app.init();
  }

  @override
  void dispose() {
    _app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unified Game Services Demo',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C5CE7),
        useMaterial3: true,
      ),
      home: DashboardScreen(app: _app),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.app});
  final AppState app;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _achId = TextEditingController(text: 'first_win');
  final _lbId = TextEditingController(text: 'high_score');
  final _score = TextEditingController(text: '1500');
  final _statKey = TextEditingController(text: 'kills');
  final _statVal = TextEditingController(text: '10');
  final _presence = TextEditingController(text: 'Playing Ranked');
  final _presenceDetails = TextEditingController(text: 'Map: Dust II');
  final _slot = TextEditingController(text: 'profile');
  final _saveText = TextEditingController(text: 'hello cloud');

  AppState get app => widget.app;

  @override
  void dispose() {
    for (final c in [
      _achId,
      _lbId,
      _score,
      _statKey,
      _statVal,
      _presence,
      _presenceDetails,
      _slot,
      _saveText,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _openConfig() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ConfigScreen(appState: app)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unified Game Services'),
        actions: [
          IconButton(
            onPressed: _openConfig,
            icon: const Icon(Icons.settings),
            tooltip: 'Configure providers',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final wide = MediaQuery.sizeOf(context).width >= 900;
          final left = _LeftColumn(app: app, onConfigure: _openConfig);
          final right = _ActionsColumn(
            app: app,
            achId: _achId,
            lbId: _lbId,
            score: _score,
            statKey: _statKey,
            statVal: _statVal,
            presence: _presence,
            presenceDetails: _presenceDetails,
            slot: _slot,
            saveText: _saveText,
          );
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SingleChildScrollView(child: left)),
                const VerticalDivider(width: 1),
                Expanded(child: SingleChildScrollView(child: right)),
              ],
            );
          }
          return SingleChildScrollView(child: Column(children: [left, right]));
        },
      ),
    );
  }
}

// ─── Left: environment + providers + capability matrix ──────────────────────

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.app, required this.onConfigure});
  final AppState app;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final build = app.build;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EnvBanner(env: app.env, active: build?.active.length ?? 0),
          const SizedBox(height: 16),
          Text('Providers', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (build != null)
            ...build.statuses.map(
              (s) => _ProviderCard(status: s, env: app.env),
            ),
          const SizedBox(height: 16),
          Text('Capabilities', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Write ops fan out to every active provider that supports the '
            'capability. Reads come from the primary (first) provider.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (build != null) _CapabilityMatrix(result: build),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onConfigure,
            icon: const Icon(Icons.settings),
            label: const Text('Configure providers'),
          ),
        ],
      ),
    );
  }
}

class _EnvBanner extends StatelessWidget {
  const _EnvBanner({required this.env, required this.active});
  final Environment env;
  final int active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              env.isWeb
                  ? Icons.public
                  : env.isDesktop
                  ? Icons.desktop_windows
                  : Icons.phone_android,
              color: cs.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Environment: ${env.description}',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$active active provider(s). dart:ffi providers '
                    '(Steam, Epic) only build on desktop.',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.status, required this.env});
  final ProviderStatus status;
  final Environment env;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (IconData icon, Color color, String label) = switch (status.state) {
      ProviderState.active => (Icons.check_circle, Colors.green, 'active'),
      ProviderState.disabled => (Icons.toggle_off, cs.outline, 'disabled'),
      ProviderState.skipped => (Icons.error_outline, cs.error, 'skipped'),
    };
    final caps = status.instance?.capabilities ?? const <GameCapability>{};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.kind.label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(label, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
            if (status.detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 28),
                child: Text(
                  status.detail!,
                  style: TextStyle(fontSize: 12, color: cs.error),
                ),
              ),
            if (caps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 28),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: caps
                      .map(
                        (c) => Chip(
                          label: Text(
                            c.name,
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityMatrix extends StatelessWidget {
  const _CapabilityMatrix({required this.result});
  final ProviderBuild result;

  static const _caps = [
    GameCapability.achievements,
    GameCapability.leaderboards,
    GameCapability.stats,
    GameCapability.cloudSave,
    GameCapability.friends,
    GameCapability.presence,
  ];

  @override
  Widget build(BuildContext context) {
    final actives = result.statuses
        .where((s) => s.state == ProviderState.active)
        .toList();
    if (actives.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No active providers yet.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18,
            headingRowHeight: 38,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 38,
            columns: [
              const DataColumn(label: Text('Capability')),
              for (final s in actives)
                DataColumn(
                  label: Text(
                    s.kind.label.split(' ').first,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
            rows: [
              for (final cap in _caps)
                DataRow(
                  cells: [
                    DataCell(Text(cap.name)),
                    for (final s in actives)
                      DataCell(
                        (s.instance!.supports(cap))
                            ? const Icon(
                                Icons.check,
                                color: Colors.green,
                                size: 18,
                              )
                            : Icon(
                                Icons.remove,
                                color: Theme.of(context).colorScheme.outline,
                                size: 18,
                              ),
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

// ─── Right: player + actions + log ──────────────────────────────────────────

class _ActionsColumn extends StatelessWidget {
  const _ActionsColumn({
    required this.app,
    required this.achId,
    required this.lbId,
    required this.score,
    required this.statKey,
    required this.statVal,
    required this.presence,
    required this.presenceDetails,
    required this.slot,
    required this.saveText,
  });

  final AppState app;
  final TextEditingController achId,
      lbId,
      score,
      statKey,
      statVal,
      presence,
      presenceDetails,
      slot,
      saveText;

  @override
  Widget build(BuildContext context) {
    final enabled = app.hasActiveProviders && !app.busy;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlayerCard(app: app),
          const SizedBox(height: 16),
          if (app.busy) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          _Section('Authentication (fan-out)', [
            _btn('Sign in', enabled ? app.signIn : null),
            _btn('Sign out', enabled ? app.signOut : null),
            _btn('Refresh player', enabled ? app.refreshPlayer : null),
          ]),
          _Section('Achievements', [
            _input(achId, 'achievement id'),
            _btn(
              'Unlock',
              enabled ? () => app.unlockAchievement(achId.text) : null,
            ),
            _btn('Read (primary)', enabled ? app.fetchAchievements : null),
          ]),
          _Section('Leaderboards', [
            _input(lbId, 'leaderboard id'),
            _input(score, 'score', width: 110, number: true),
            _btn(
              'Submit score',
              enabled
                  ? () => app.submitScore(
                      lbId.text,
                      int.tryParse(score.text) ?? 0,
                    )
                  : null,
            ),
          ]),
          _Section('Stats', [
            _input(statKey, 'stat key'),
            _input(statVal, 'value', width: 110, number: true),
            _btn(
              'Set stat',
              enabled
                  ? () => app.setStat(
                      statKey.text,
                      num.tryParse(statVal.text) ?? 0,
                    )
                  : null,
            ),
          ]),
          _Section('Presence', [
            _input(presence, 'state'),
            _input(presenceDetails, 'details'),
            _btn(
              'Set presence',
              enabled
                  ? () => app.setPresence(presence.text, presenceDetails.text)
                  : null,
            ),
          ]),
          _Section('Cloud save', [
            _input(slot, 'slot'),
            _input(saveText, 'payload (utf-8)'),
            _btn(
              'Save',
              enabled ? () => app.saveData(slot.text, saveText.text) : null,
            ),
            _btn(
              'Load (primary)',
              enabled ? () => app.loadData(slot.text) : null,
            ),
          ]),
          _Section('Friends', [
            _btn('Read (primary)', enabled ? app.fetchFriends : null),
          ]),
          const SizedBox(height: 16),
          Text('Activity', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _LogView(app: app),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback? onTap) =>
      FilledButton.tonal(onPressed: onTap, child: Text(label));

  Widget _input(
    TextEditingController c,
    String label, {
    double width = 200,
    bool number = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final p = app.currentPlayer;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(p?.displayName ?? 'Not signed in'),
        subtitle: Text(p == null ? '—' : 'id: ${p.id}'),
      ),
    );
  }
}

class _LogView extends StatelessWidget {
  const _LogView({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: app.log.length,
        itemBuilder: (context, i) {
          final e = app.log[i];
          final color = e.kind == 'event'
              ? cs.primary
              : e.ok
              ? cs.onSurface
              : cs.error;
          return Text(
            e.message,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: color,
            ),
          );
        },
      ),
    );
  }
}
