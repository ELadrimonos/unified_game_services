import 'dart:io';
import 'package:flutter/material.dart';
import 'package:unified_game_services_epic/unified_game_services_epic.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

void main() {
  runApp(const EosExampleApp());
}

class EosExampleApp extends StatelessWidget {
  const EosExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EOS Flutter Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4FF),
          surface: Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
      ),
      home: const EosHomeScreen(),
    );
  }
}

class EosHomeScreen extends StatefulWidget {
  const EosHomeScreen({super.key});

  @override
  State<EosHomeScreen> createState() => _EosHomeScreenState();
}

enum _AppState { idle, signingIn, ready, error }

class _EosHomeScreenState extends State<EosHomeScreen> {
  EpicProvider? _provider;
  _AppState _appState = _AppState.idle;
  PlayerProfile? _player;
  String? _errorMessage;

  List<Achievement> _achievements = [];
  bool _loadingAchievements = false;

  List<PlayerProfile> _friends = [];
  bool _loadingFriends = false;
  String? _friendsError;

  // ── Campos del formulario (prefill desde env / --dart-define si existe) ─────
  late final _fields = <String, TextEditingController>{
    'EOS_PRODUCT_ID': TextEditingController(text: _envOrNull('EOS_PRODUCT_ID')),
    'EOS_SANDBOX_ID': TextEditingController(text: _envOrNull('EOS_SANDBOX_ID')),
    'EOS_DEPLOYMENT_ID':
        TextEditingController(text: _envOrNull('EOS_DEPLOYMENT_ID')),
    'EOS_CLIENT_ID': TextEditingController(text: _envOrNull('EOS_CLIENT_ID')),
    'EOS_CLIENT_SECRET':
        TextEditingController(text: _envOrNull('EOS_CLIENT_SECRET')),
    'EOS_DEV_AUTH_HOST': TextEditingController(
        text: _envOrNull('EOS_DEV_AUTH_HOST') ?? 'localhost:20304'),
    'EOS_DEV_AUTH_CRED':
        TextEditingController(text: _envOrNull('EOS_DEV_AUTH_CRED')),
    'EOS_SDK_DIR': TextEditingController(text: _envOrNull('EOS_SDK_DIR')),
  };

  String _field(String key) => _fields[key]!.text.trim();
  String? _fieldOrNull(String key) {
    final v = _field(key);
    return v.isEmpty ? null : v;
  }

  // ── SDK path ──────────────────────────────────────────────────────────────
  String? _sdkLibraryPath() {
    final sdkDir = _fieldOrNull('EOS_SDK_DIR');
    if (sdkDir == null) return null;
    if (Platform.isMacOS) return '$sdkDir/Bin/libEOSSDK-Mac-Shipping.dylib';
    if (Platform.isWindows) return '$sdkDir/Bin/x64/EOSSDK-Win64-Shipping.dll';
    if (Platform.isLinux) return '$sdkDir/Bin/libEOSSDK-Linux-Shipping.so';
    return null;
  }

  // ── Credentials ───────────────────────────────────────────────────────────
  String? _envOrNull(String key) {
    final fromDefine = String.fromEnvironment(key);
    if (fromDefine.isNotEmpty) return fromDefine;
    return Platform.environment[key];
  }

  // ── Sign in ───────────────────────────────────────────────────────────────
  Future<void> _signIn() async {
    setState(() {
      _appState = _AppState.signingIn;
      _errorMessage = null;
    });

    try {
      _provider ??= EpicProvider(
        debugLogging: true,
        credentials: EpicCredentials(
          productId: _field('EOS_PRODUCT_ID'),
          sandboxId: _field('EOS_SANDBOX_ID'),
          deploymentId: _field('EOS_DEPLOYMENT_ID'),
          clientId: _field('EOS_CLIENT_ID'),
          clientSecret: _field('EOS_CLIENT_SECRET'),
        ),
        // Developer Auth Tool → real EAS login (profile + friends) with no
        // launcher. Leave these fields empty to fall back to anonymous Device
        // ID login.
        devAuthHost: _fieldOrNull('EOS_DEV_AUTH_HOST'),
        devAuthCredentialName: _fieldOrNull('EOS_DEV_AUTH_CRED'),
        libraryPath: _sdkLibraryPath(),
        achievementIds: {
          'TEST': 'TEST_ACHIEVEMENT'
        }
      );

      final player = await _provider!.signIn();
      setState(() {
        _player = player;
        _appState = _AppState.ready;
      });

      await _loadAchievements();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _appState = _AppState.error;
      });
    }
  }

  // ── Load achievements ─────────────────────────────────────────────────────
  Future<void> _loadAchievements() async {
    if (_provider == null) return;
    setState(() => _loadingAchievements = true);
    try {
      final list = await _provider!.getAchievements();
      setState(() => _achievements = list);
    } catch (e) {
      debugPrint('Error loading achievements: $e');
    } finally {
      setState(() => _loadingAchievements = false);
    }
  }

  // ── Load friends (EAS only) ───────────────────────────────────────────────
  Future<void> _loadFriends() async {
    if (_provider == null) return;
    setState(() {
      _loadingFriends = true;
      _friendsError = null;
    });
    try {
      final list = await _provider!.getFriends();
      setState(() => _friends = list);
    } catch (e) {
      setState(() => _friendsError = e.toString());
    } finally {
      setState(() => _loadingFriends = false);
    }
  }

  // ── Unlock achievement ────────────────────────────────────────────────────
  Future<void> _unlock(Achievement achievement) async {
    if (_provider == null || achievement.isUnlocked) return;
    try {
      await _provider!.unlockAchievement(achievement.id);
      await _loadAchievements(); // Refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🏆 "${achievement.title}" unlocked!'),
            backgroundColor: const Color(0xFF00D4FF).withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _provider?.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_appState) {
          _AppState.idle   => _buildIdle(),
          _AppState.signingIn => _buildLoading('Signing in to Epic Games...'),
          _AppState.ready  => _buildDashboard(),
          _AppState.error  => _buildError(),
        },
      ),
    );
  }

  // ── Idle screen ───────────────────────────────────────────────────────────
  Widget _buildIdle() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.sports_esports,
                  size: 64, color: Color(0xFF00D4FF)),
              const SizedBox(height: 12),
              const Text('EOS Flutter Test',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              const SizedBox(height: 24),
              const Text('Credentials (Dev Portal)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _formField('EOS_PRODUCT_ID', 'Product ID'),
              _formField('EOS_SANDBOX_ID', 'Sandbox ID'),
              _formField('EOS_DEPLOYMENT_ID', 'Deployment ID'),
              _formField('EOS_CLIENT_ID', 'Client ID'),
              _formField('EOS_CLIENT_SECRET', 'Client Secret', obscure: true),
              const SizedBox(height: 16),
              const Text('Developer Auth Tool (real EAS login)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Empty → anonymous Device ID login (no real profile or friends).',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 8),
              _formField('EOS_DEV_AUTH_HOST', 'Host (e.g. 127.0.0.1:20304)'),
              _formField('EOS_DEV_AUTH_CRED', 'Credential name'),
              const SizedBox(height: 16),
              const Text('SDK', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _formField('EOS_SDK_DIR',
                  'EOS_SDK_DIR path (empty = dylib on PATH/rpath)'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _signIn,
                icon: const Icon(Icons.login),
                label: const Text('Sign In'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formField(String key, String label, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: _fields[key],
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  // ── Loading screen ────────────────────────────────────────────────────────
  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00D4FF)),
          const SizedBox(height: 24),
          Text(message, style: TextStyle(color: Colors.white.withOpacity(0.7))),
        ],
      ),
    );
  }

  // ── Error screen ──────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text('Sign-in error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage ?? '',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => setState(() => _appState = _AppState.idle),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────
  Widget _buildDashboard() {
    final unlocked = _achievements.where((a) => a.isUnlocked).length;
    final total = _achievements.length;
    final progress = total > 0 ? unlocked / total : 0.0;

    return CustomScrollView(
      slivers: [
        // App bar con info del jugador
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          backgroundColor: const Color(0xFF0F0F1A),
          flexibleSpace: FlexibleSpaceBar(
            background: _buildPlayerHeader(unlocked, total, progress),
          ),
          actions: [
            IconButton(
              tooltip: 'Reload achievements',
              onPressed: _loadingAchievements ? null : _loadAchievements,
              icon: _loadingAchievements
                  ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),

        // Panel de amigos (EAS)
        SliverToBoxAdapter(child: _buildFriendsPanel()),

        // Achievement list
        if (_loadingAchievements && _achievements.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF))),
          )
        else if (_achievements.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 64, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text('No achievements available',
                      style: TextStyle(color: Colors.white.withOpacity(0.5))),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: _achievements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _AchievementCard(
                achievement: _achievements[i],
                onUnlock: () => _unlock(_achievements[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFriendsPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt, color: Color(0xFF00D4FF), size: 20),
              const SizedBox(width: 8),
              const Text('Epic Friends',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _loadingFriends ? null : _loadFriends,
                icon: _loadingFriends
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download, size: 18),
                label: const Text('Load'),
              ),
            ],
          ),
          if (_friendsError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _friendsError!,
                style: const TextStyle(
                    color: Colors.redAccent, fontSize: 12, fontFamily: 'monospace'),
              ),
            )
          else if (_friends.isEmpty && !_loadingFriends)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No friends loaded.',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            )
          else
            ..._friends.map(
              (f) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0x3300D4FF),
                  child: Icon(Icons.person, size: 18, color: Color(0xFF00D4FF)),
                ),
                title: Text(f.displayName),
                subtitle: Text(f.id,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 10)),
              ),
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _buildPlayerHeader(int unlocked, int total, double progress) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF00D4FF).withOpacity(0.2),
                child: const Icon(Icons.person, color: Color(0xFF00D4FF), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_player?.displayName ?? 'Connected player',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      _player != null
                          ? '${_player!.id.substring(0, 8)}...${_player!.id.substring(_player!.id.length - 6)}'
                          : '—',
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFF00D4FF)),
                    ),
                  ],
                ),
              ),
              _StatBadge(label: 'Logros', value: '$unlocked / $total'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00D4FF)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% completed',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Achievement card ──────────────────────────────────────────────────────────
class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement, required this.onUnlock});

  final Achievement achievement;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked;
    final accent = unlocked ? const Color(0xFFFFD700) : Colors.white30;

    return Card(
      child: InkWell(
        onTap: unlocked ? null : onUnlock,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon / trophy
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.4), width: 1.5),
                ),
                child: achievement.iconUrl != null ?
                    Image.network(achievement.iconUrl!)
                    : Icon(
                  unlocked ? Icons.emoji_events : Icons.lock_outline,
                  color: accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),

              // Name + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: unlocked ? Colors.white : Colors.white70,
                      ),
                    ),
                    if (achievement.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        achievement.description ?? 'No description',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (achievement.unlockedAt != null) ... [
                      const SizedBox(height: 4),
                      Text(
                        achievement.unlockedAt!.toUtc().toString(),
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Status badge
              _StatusChip(unlocked: unlocked),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chips y badges ────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.unlocked});
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: unlocked
            ? const Color(0xFFFFD700).withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked ? const Color(0xFFFFD700).withOpacity(0.5) : Colors.white12,
        ),
      ),
      child: Text(
        unlocked ? '✓ Unlocked' : 'Locked',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: unlocked ? const Color(0xFFFFD700) : Colors.white38,
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00D4FF))),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}