import 'package:flutter/material.dart';

import '../app_state.dart';
import '../env.dart';

/// Per-provider credential form. Edits live controllers seeded from the
/// persisted config; "Save" writes them back, persists to shared_preferences
/// and reassembles the facade. Nothing leaves the device.
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late final Map<String, TextEditingController> _c;
  late bool _gjOn, _gpOn, _steamOn, _epicOn;

  AppState get app => widget.appState;
  Environment get env => app.env;

  @override
  void initState() {
    super.initState();
    final cfg = app.config;
    _gjOn = cfg.gameJolt.enabled;
    _gpOn = cfg.googlePlay.enabled;
    _steamOn = cfg.steam.enabled;
    _epicOn = cfg.epic.enabled;
    _c = {
      'gj.gameId': TextEditingController(text: cfg.gameJolt.gameId),
      'gj.privateKey': TextEditingController(text: cfg.gameJolt.privateKey),
      'gj.username': TextEditingController(text: cfg.gameJolt.username),
      'gj.userToken': TextEditingController(text: cfg.gameJolt.userToken),
      'gj.ach': TextEditingController(text: cfg.gameJolt.achievementIdsRaw),
      'gj.lb': TextEditingController(text: cfg.gameJolt.leaderboardIdsRaw),
      'gp.clientId': TextEditingController(text: cfg.googlePlay.oauthClientId),
      'gp.secret': TextEditingController(
        text: cfg.googlePlay.oauthClientSecret,
      ),
      'gp.ach': TextEditingController(text: cfg.googlePlay.achievementIdsRaw),
      'gp.lb': TextEditingController(text: cfg.googlePlay.leaderboardIdsRaw),
      'st.appId': TextEditingController(text: cfg.steam.appId),
      'st.ach': TextEditingController(text: cfg.steam.achievementIdsRaw),
      'st.lb': TextEditingController(text: cfg.steam.leaderboardIdsRaw),
      'ep.productId': TextEditingController(text: cfg.epic.productId),
      'ep.sandboxId': TextEditingController(text: cfg.epic.sandboxId),
      'ep.deploymentId': TextEditingController(text: cfg.epic.deploymentId),
      'ep.clientId': TextEditingController(text: cfg.epic.clientId),
      'ep.clientSecret': TextEditingController(text: cfg.epic.clientSecret),
      'ep.encKey': TextEditingController(text: cfg.epic.encryptionKey),
      'ep.devHost': TextEditingController(text: cfg.epic.devAuthHost),
      'ep.devCred': TextEditingController(text: cfg.epic.devAuthCredentialName),
      'ep.ach': TextEditingController(text: cfg.epic.achievementIdsRaw),
      'ep.lb': TextEditingController(text: cfg.epic.leaderboardIdsRaw),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(String k) => _c[k]!.text;

  Future<void> _save() async {
    final cfg = app.config;
    cfg.gameJolt
      ..enabled = _gjOn
      ..gameId = _v('gj.gameId')
      ..privateKey = _v('gj.privateKey')
      ..username = _v('gj.username')
      ..userToken = _v('gj.userToken')
      ..achievementIdsRaw = _v('gj.ach')
      ..leaderboardIdsRaw = _v('gj.lb');
    cfg.googlePlay
      ..enabled = _gpOn
      ..oauthClientId = _v('gp.clientId')
      ..oauthClientSecret = _v('gp.secret')
      ..achievementIdsRaw = _v('gp.ach')
      ..leaderboardIdsRaw = _v('gp.lb');
    cfg.steam
      ..enabled = _steamOn
      ..appId = _v('st.appId')
      ..achievementIdsRaw = _v('st.ach')
      ..leaderboardIdsRaw = _v('st.lb');
    cfg.epic
      ..enabled = _epicOn
      ..productId = _v('ep.productId')
      ..sandboxId = _v('ep.sandboxId')
      ..deploymentId = _v('ep.deploymentId')
      ..clientId = _v('ep.clientId')
      ..clientSecret = _v('ep.clientSecret')
      ..encryptionKey = _v('ep.encKey')
      ..devAuthHost = _v('ep.devHost')
      ..devAuthCredentialName = _v('ep.devCred')
      ..achievementIdsRaw = _v('ep.ach')
      ..leaderboardIdsRaw = _v('ep.lb');

    await app.saveAndRebuild();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider configuration'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            kind: ProviderKind.gameJolt,
            enabled: _gjOn,
            onToggle: (v) => setState(() => _gjOn = v),
            fields: [
              _field('gj.gameId', 'Game ID'),
              _field('gj.privateKey', 'Private key', obscure: true),
              _field('gj.username', 'Username'),
              _field('gj.userToken', 'User token', obscure: true),
              _idMaps('gj.ach', 'gj.lb'),
            ],
          ),
          _section(
            kind: ProviderKind.googlePlay,
            enabled: _gpOn,
            onToggle: (v) => setState(() => _gpOn = v),
            fields: [
              if (!env.isAndroid) ...[
                _field('gp.clientId', 'Desktop OAuth client id'),
                _field(
                  'gp.secret',
                  'OAuth client secret (optional)',
                  obscure: true,
                ),
              ] else
                const _Note(
                  'On Android the native Play Games client brokers the token '
                  '— no OAuth fields needed.',
                ),
              _idMaps('gp.ach', 'gp.lb'),
            ],
          ),
          _section(
            kind: ProviderKind.steam,
            enabled: _steamOn,
            onToggle: (v) => setState(() => _steamOn = v),
            fields: [
              _field(
                'st.appId',
                'App ID (optional if steam_appid.txt present)',
                keyboard: TextInputType.number,
              ),
              _idMaps('st.ach', 'st.lb'),
            ],
          ),
          _section(
            kind: ProviderKind.epic,
            enabled: _epicOn,
            onToggle: (v) => setState(() => _epicOn = v),
            fields: [
              _field('ep.productId', 'Product ID'),
              _field('ep.sandboxId', 'Sandbox ID'),
              _field('ep.deploymentId', 'Deployment ID'),
              _field('ep.clientId', 'Client ID'),
              _field('ep.clientSecret', 'Client secret', obscure: true),
              _field(
                'ep.encKey',
                'Encryption key (64 hex — needed for cloud save)',
                obscure: true,
              ),
              const _Note('Dev Auth Tool login (recommended for development):'),
              _field('ep.devHost', 'Dev auth host (e.g. localhost:6300)'),
              _field('ep.devCred', 'Dev auth credential name'),
              _idMaps('ep.ach', 'ep.lb'),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _section({
    required ProviderKind kind,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required List<Widget> fields,
  }) {
    final reason = env.unavailableReason(kind);
    final available = reason == null;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kind.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        kind.transport,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(value: enabled, onChanged: onToggle),
              ],
            ),
            if (!available)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _Note('⚠ $reason', warn: true),
              ),
            if (enabled) ...[const Divider(height: 24), ...fields],
          ],
        ),
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _c[key],
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _idMaps(String achKey, String lbKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Note(
          'Optional unified→native id maps, one "unified=native" per line. '
          'Lets a single facade call hit every provider with its own ids.',
        ),
        const SizedBox(height: 8),
        _multiline(achKey, 'Achievement ids  (e.g. first_win=CgkI...)'),
        const SizedBox(height: 12),
        _multiline(lbKey, 'Leaderboard ids  (e.g. high_score=CgkI...)'),
      ],
    );
  }

  Widget _multiline(String key, String label) {
    return TextField(
      controller: _c[key],
      minLines: 1,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.warn = false});
  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Text(text, style: TextStyle(fontSize: 12, color: color));
  }
}
