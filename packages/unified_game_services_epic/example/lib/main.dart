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
  String? _playerId;
  String? _errorMessage;

  List<Achievement> _achievements = [];
  bool _loadingAchievements = false;

  // ── SDK path ──────────────────────────────────────────────────────────────
  String? _sdkLibraryPath() {
    final sdkDir = Platform.environment['EOS_SDK_DIR'];
    if (sdkDir == null) return null;
    if (Platform.isMacOS) return '$sdkDir/Bin/libEOSSDK-Mac-Shipping.dylib';
    if (Platform.isWindows) return '$sdkDir/Bin/x64/EOSSDK-Win64-Shipping.dll';
    if (Platform.isLinux) return '$sdkDir/Bin/libEOSSDK-Linux-Shipping.so';
    return null;
  }

  // ── Credentials ───────────────────────────────────────────────────────────
  String _env(String key) {
    final v = String.fromEnvironment(key).isNotEmpty
        ? String.fromEnvironment(key)
        : Platform.environment[key];
    if (v == null || v.isEmpty) throw Exception('Falta la credencial: $key');
    return v;
  }

  // ── Sign in ───────────────────────────────────────────────────────────────
  Future<void> _signIn() async {
    setState(() {
      _appState = _AppState.signingIn;
      _errorMessage = null;
    });

    try {
      _provider ??= EpicProvider(
        credentials: EpicCredentials(
          productId: _env('EOS_PRODUCT_ID'),
          sandboxId: _env('EOS_SANDBOX_ID'),
          deploymentId: _env('EOS_DEPLOYMENT_ID'),
          clientId: _env('EOS_CLIENT_ID'),
          clientSecret: _env('EOS_CLIENT_SECRET'),
        ),
        libraryPath: _sdkLibraryPath(),
        achievementIds: {
          'TEST': 'TEST_ACHIEVEMENT'
        }
      );

      final player = await _provider!.signIn();
      setState(() {
        _playerId = player?.id;
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
      debugPrint('Error cargando logros: $e');
    } finally {
      setState(() => _loadingAchievements = false);
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
            content: Text('🏆 "${achievement.title}" desbloqueado!'),
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
          _AppState.signingIn => _buildLoading('Iniciando sesión en Epic Games...'),
          _AppState.ready  => _buildDashboard(),
          _AppState.error  => _buildError(),
        },
      ),
    );
  }

  // ── Idle screen ───────────────────────────────────────────────────────────
  Widget _buildIdle() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_esports, size: 80, color: Color(0xFF00D4FF)),
          const SizedBox(height: 24),
          const Text(
            'EOS Flutter Test',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            'Epic Online Services SDK',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: _signIn,
            icon: const Icon(Icons.login),
            label: const Text('Iniciar Sesión'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ],
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
            const Text('Error al iniciar sesión',
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
              label: const Text('Reintentar'),
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
              tooltip: 'Recargar logros',
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

        // Lista de logros
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
                  Text('Sin logros disponibles',
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
                    const Text('Jugador conectado',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(
                      _playerId != null
                          ? '${_playerId!.substring(0, 8)}...${_playerId!.substring(_playerId!.length - 6)}'
                          : '—',
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
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
            '${(progress * 100).toStringAsFixed(0)}% completado',
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
              // Icono / trofeo
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

              // Nombre + descripción
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

              // Badge estado
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
        unlocked ? '✓ Obtenido' : 'Bloqueado',
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