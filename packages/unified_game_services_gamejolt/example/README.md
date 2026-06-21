# GameJolt examples

## Real login + integration playground

`interactive_login.dart` logs into the **real** GameJolt API with a player
profile and lets you exercise every feature from a menu.

```sh
dart run example/interactive_login.dart
```

It prompts for any credential not already in the environment, so you can also do:

```sh
export GAMEJOLT_GAME_ID=123456
export GAMEJOLT_PRIVATE_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
export GAMEJOLT_USERNAME=your_name
export GAMEJOLT_USER_TOKEN=xxxxxxxx
dart run example/interactive_login.dart
```

## Getting the credentials

You need **two pairs**: the game's keys (developer) and a player's token.

### 1. Game ID + Private Key (the game)

You must own a game on GameJolt — creating one is free and takes a minute.

1. Sign in at <https://gamejolt.com> and go to your **Game Dashboard**
   (`Dashboard → Games → [your game]`). Create a game first if you have none.
2. Open **Game API → API Settings**.
3. Copy the **Game ID** and **Private Key**.
4. Enable the Game API and add some **Trophies** (achievements) and a
   **Score Table** (leaderboard) there if you want to test those — note their
   ids.

### 2. Username + Game Token (the player)

Any GameJolt user (you'll do) can play:

1. Sign in at <https://gamejolt.com>.
2. Open the profile menu → **Game Token** (or
   <https://gamejolt.com/profile>), and reveal the **Game Token**.
3. Use your **username** and that **Game Token** — note this is *not* your
   password.

## Notes

- Unlocking trophies and submitting scores are **real writes** to your game.
- The cloud-save test writes and then deletes a key named `ugs_demo`.
- For a non-interactive/CI run see `../tool/smoke_test.dart`.
