import 'package:flutter/material.dart';
import 'package:unified_game_services/unified_game_services.dart';

import '../app_state.dart';
import '../services/steam_game_names.dart';

/// Shows the signed-in player and their friends: avatar, level, online state
/// and rich presence, as far as the primary provider exposes them.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.app});
  final AppState app;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // loadSocial notifies listeners, which is not allowed during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.app.hasActiveProviders) widget.app.loadSocial();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final app = widget.app;
        final me = app.currentPlayer;
        final friends = [...app.friends]
          ..sort((a, b) {
            final byOnline = (b.isOnline == true ? 1 : 0).compareTo(
              a.isOnline == true ? 1 : 0,
            );
            return byOnline != 0
                ? byOnline
                : a.displayName.toLowerCase().compareTo(
                    b.displayName.toLowerCase(),
                  );
          });
        final online = friends.where((f) => f.isOnline == true).length;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile & friends'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: app.hasActiveProviders && !app.busy
                    ? app.loadSocial
                    : null,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Column(
            children: [
              if (app.busy) const LinearProgressIndicator(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (me == null)
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.person_off),
                          title: Text('Not signed in'),
                          subtitle: Text('Sign in from the dashboard first.'),
                        ),
                      )
                    else
                      _ProfileHeader(player: me, names: app.gameNames),
                    const SizedBox(height: 24),
                    Text(
                      'Friends (${friends.length}, $online online)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (friends.isEmpty)
                      const Text('No friends loaded.')
                    else
                      for (final f in friends)
                        _FriendTile(player: f, names: app.gameNames),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Avatar from [PlayerProfile.avatarBytes] or [PlayerProfile.avatarUrl], with
/// the initial of the name as fallback, and a presence dot when [showDot].
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.player,
    this.radius = 20,
    this.showDot = false,
  });

  final PlayerProfile player;
  final double radius;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final bytes = player.avatarBytes;
    final url = player.avatarUrl;
    final ImageProvider? image = bytes != null
        ? MemoryImage(bytes)
        : url != null
        ? NetworkImage(url)
        : null;
    final initial = player.displayName.isEmpty
        ? '?'
        : player.displayName.characters.first.toUpperCase();
    final avatar = CircleAvatar(
      radius: radius,
      backgroundImage: image,
      onBackgroundImageError: image == null ? null : (_, _) {},
      child: image == null ? Text(initial) : null,
    );
    if (!showDot) return avatar;
    final online = player.isOnline == true;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: radius * 0.6,
            height: radius * 0.6,
            decoration: BoxDecoration(
              color: online ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `Playing <game>` for the game in `extra['gameId']`, if any. Falls back to a
/// generic "In game" until the name is resolved; never shows the raw app id.
String? _playing(PlayerProfile p, SteamGameNames names) {
  final id = p.extra['gameId'];
  if (id is! int) return null;
  final name = names[id];
  return name == null ? 'In game' : 'Playing $name';
}

/// One-line activity text: rich presence, else the persona state, else
/// online/offline.
String _statusLine(PlayerProfile p) {
  final presence = p.presence;
  if (presence != null) {
    final details = presence.details;
    return details == null ? presence.state : '${presence.state} · $details';
  }
  final persona = p.extra['personaState'];
  if (persona is String) return persona;
  return p.isOnline == true ? 'online' : 'offline';
}

/// Extra badges: Steam level, game being played, party size.
List<String> _badges(PlayerProfile p, SteamGameNames names) => [
  ?p.title,
  ?_playing(p, names),
  if (p.presence?.partySize case final int size)
    'Party $size${p.presence?.partyMax == null ? '' : '/${p.presence!.partyMax}'}',
];

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.player, required this.names});
  final PlayerProfile player;
  final SteamGameNames names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nickname = player.extra['nickname'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            PlayerAvatar(player: player, radius: 44, showDot: true),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.displayName, style: theme.textTheme.titleLarge),
                  if (nickname is String) Text('aka $nickname'),
                  const SizedBox(height: 4),
                  Text(_statusLine(player)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final b in _badges(player, names))
                        Chip(
                          label: Text(b),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'id: ${player.id}'
                    '${player.providerId == null ? '' : ' · ${player.providerId}'}',
                    style: theme.textTheme.bodySmall,
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

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.player, required this.names});
  final PlayerProfile player;
  final SteamGameNames names;

  @override
  Widget build(BuildContext context) {
    final offline = player.isOnline != true;
    final badges = _badges(player, names);
    return Opacity(
      opacity: offline ? 0.55 : 1,
      child: ListTile(
        leading: PlayerAvatar(player: player, showDot: true),
        title: Text(player.displayName),
        subtitle: Text(
          [_statusLine(player), ...badges].join('  ·  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
