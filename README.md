# Unified Game Services for Flutter

Una capa de abstracción multiplataforma para servicios de videojuegos que unifica logros, clasificaciones, estadísticas, guardado en la nube, perfiles de usuario y presencia online mediante una única API Flutter.

## Objetivos

- Una única API para múltiples plataformas.
- Arquitectura modular basada en plugins.
- Compatibilidad con móvil, escritorio y consola.
- Integración sencilla para desarrolladores Flutter.
- Extensible para nuevos proveedores sin modificar el núcleo.

---

## Estado del proyecto

| Módulo | Estado |
|---------|---------|
| Core API | ✅ Implementado (interface + facade multi-provider) |
| Achievements | 🚧 Diseño |
| Leaderboards | 🚧 Diseño |
| Stats | 🚧 Diseño |
| Cloud Save | 📋 Planificado |
| User Profiles | 📋 Planificado |
| Rich Presence | 📋 Planificado |
| Steam | ✅ Implementado (Dart puro, FFI `steamworks`) — pendiente verificación en runtime Windows |
| GameJolt | ✅ Implementado (Dart puro, REST Game API v1.2) — verificado con tests (MockClient) |
| Epic Online Services | 🚧 MVP (Dart puro, EOS REST/C) |
| Google Play Games | ⏸️ Aplazado (sin vía Dart puro) |
| Apple Game Center | ⏸️ Aplazado (posible vía FFI/GameKit) |
| Xbox Live | 📋 Investigación |
| Huawei Game Service | 📋 Investigación |

> **Restricción núcleo:** ningún paquete depende de Flutter. Por eso no se usa
> [`games_services`](https://pub.dev/packages/games_services) (requiere Flutter +
> platform channels). El MVP cubre los proveedores accesibles desde Dart puro;
> Google Play y Game Center quedan aplazados.

---

## Visión

Actualmente Flutter dispone de soluciones independientes para algunas plataformas, pero no existe una interfaz unificada que permita escribir una única implementación y desplegarla en múltiples ecosistemas.

Este proyecto busca resolver ese problema.

```dart
final gameServices = UnifiedGameServices();

await gameServices.unlockAchievement(
  'first_win',
);

await gameServices.submitScore(
  leaderboardId: 'global_score',
  score: 1500,
);
```

La misma llamada funcionará sobre:

- Google Play Games
- Apple Game Center
- Steam
- Epic Games Store
- GameJolt
- Xbox Live
- Otros proveedores futuros

---

## Arquitectura

```text
unified_game_services
│
├── core
│   ├── achievements
│   ├── leaderboards
│   ├── stats
│   ├── profiles
│   ├── cloud_save
│   └── presence
│
├── providers
│   ├── google_play
│   ├── game_center
│   ├── steam
│   ├── epic
│   ├── xbox
│   ├── gamejolt
│   └── huawei
│
└── platform_interfaces
```

---

## Monorepo recomendado

```text
packages/
│
├── unified_game_services
├── unified_game_services_platform_interface
├── unified_game_services_google_play
├── unified_game_services_game_center
├── unified_game_services_steam
├── unified_game_services_epic
├── unified_game_services_gamejolt
├── unified_game_services_xbox
└── examples/
```

---

## Roadmap

### Fase 1 — Core

**Objetivo**

Construir la API base sin depender de ninguna plataforma.

**Tareas**

- Definir `GameProvider`.
- Definir `Achievement`.
- Definir `Leaderboard`.
- Definir `PlayerProfile`.
- Definir `Stat`.
- Definir `CloudSave`.
- Definir `RichPresence`.
- Definir excepciones comunes.
- Definir sistema de capacidades.

### Fase 2 — Achievements

**API inicial**

```dart
await services.unlockAchievement(
  'achievement_id',
);
```

**Funcionalidades**

- Desbloquear logro.
- Logros incrementales.
- Obtener progreso.
- Obtener listado completo.
- Eventos de cambio.

### Fase 3 — Leaderboards

**API inicial**

```dart
await services.submitScore(
  leaderboardId: 'global',
  score: 1000,
);
```

**Funcionalidades**

- Enviar puntuación.
- Obtener top global.
- Obtener puntuación personal.
- Obtener ranking.
- Obtener puntuaciones de amigos.

### Fase 4 — Stats

**API inicial**

```dart
await services.setStat(
  key: 'kills',
  value: 150,
);
```

**Funcionalidades**

- Leer estadísticas.
- Actualizar estadísticas.
- Incrementar estadísticas.
- Sincronización automática.

### Fase 5 — Profiles

**API inicial**

```dart
final player = await services.getCurrentPlayer();
```

**Funcionalidades**

- ID usuario.
- Nombre visible.
- Avatar.
- Estado online.
- Amigos.

### Fase 6 — Rich Presence

**API inicial**

```dart
await services.setPresence(
  state: 'Playing Ranked',
);
```

**Funcionalidades**

- Estado personalizado.
- Tiempo de sesión.
- Actividad actual.
- Invitaciones.

### Fase 7 — Cloud Save

**API inicial**

```dart
await services.saveData(
  slot: 'profile',
  data: bytes,
);
```

**Funcionalidades**

- Guardado remoto.
- Versionado.
- Resolución de conflictos.
- Sincronización offline.

---

## Sistema de capacidades

Cada plataforma soporta características diferentes.

```dart
if (services.supports(
  GameCapability.cloudSave,
)) {
  ...
}
```

Capacidades previstas:

```dart
enum GameCapability {
  achievements,
  leaderboards,
  stats,
  cloudSave,
  friends,
  presence,
  multiplayer,
}
```

---

## Multi Provider

Permite publicar simultáneamente en varias plataformas.

```dart
final services = UnifiedGameServices(
  providers: [
    SteamProvider(),
    EpicProvider(),
    GameJoltProvider(),
  ],
);
```

Las operaciones se ejecutan sobre todos los proveedores compatibles.

---

## Eventos

```dart
services.events.listen(
  (event) {
    print(event);
  },
);
```

Eventos previstos:

- AchievementUnlocked
- ScoreSubmitted
- StatUpdated
- PresenceChanged
- UserSignedIn

---

## Testing

### Core

- Unit tests
- Mock providers

### Providers

- Integration tests
- Fake SDKs
- CI multiplataforma

---

## Futuras expansiones

### Multiplayer

```dart
await services.inviteFriend();
```

### Matchmaking

```dart
await services.findMatch();
```

### Anti-Cheat

Sistema opcional para proveedores compatibles.

### Analytics

```dart
await services.trackEvent(
  'boss_defeated',
);
```

---

## MVP recomendado

### Core

- Arquitectura base.
- Achievements.
- Leaderboards.

### Proveedores

- Google Play Games.
- Apple Game Center.
- Steam.

### Publicación

- Documentación.
- Ejemplo completo.
- Tests.
- CI.

---

## Objetivo final

Convertirse en la solución estándar de Flutter para servicios de videojuegos, permitiendo escribir una única integración y desplegarla sobre cualquier ecosistema de distribución de juegos.