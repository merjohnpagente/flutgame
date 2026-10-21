# Dungeon Co-op

A small co-op dungeon game: up to 4 players share one arena, fight waves of slimes, and try to beat their best wave. The Flutter app is a thin client; a Node server owns movement, enemies, damage and wave state, so nobody can cheat by editing the app.

```
server/   Node + ws authoritative room (one dependency)
app/      Flutter client (Canvas rendering, no game engine)
```

## Run the server

```sh
cd server
npm install
npm start
```

Listens on `ws://0.0.0.0:8080` (override with `PORT=9000 npm start`). Open the port on your firewall if a phone will connect.

## Run the app

Requires Flutter 3.22 or newer.

```sh
cd app
flutter create --empty --platforms=android,linux,windows --project-name dungeon_coop .
flutter pub get
flutter run -d linux      # or: -d windows / -d macos (add macos to --platforms)
```

`flutter create` only fills in the platform folders; it does not overwrite `lib/` or `pubspec.yaml` unless you pass `--overwrite`.

No local Flutter needed: `.github/workflows/build.yml` tests the server and builds a release APK on GitHub Actions. Pushing the repo and opening the **Actions** tab produces a `dungeon-coop-apk` artifact. The workflow adds the Android internet permission automatically.

Server address defaults to `ws://localhost:8080` for desktop. Set it at build time or edit the field on the join screen:

```sh
# Android emulator
flutter run --dart-define=SERVER_URL=ws://10.0.2.2:8080

# Physical phone on the same Wi-Fi (find your computer's LAN IP)
flutter run --dart-define=SERVER_URL=ws://192.168.1.20:8080
```

For a **local release** Android build, add internet permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Debug builds already have it via Flutter's debug manifest.

## Controls

- Move: WASD / arrow keys, or drag the on-screen joystick.
- Attack: automatic at the nearest slime in range.
- Phones run in landscape; 4 players maximum.

## Tests

```sh
cd server && npm test     # game logic + two real WebSocket clients
cd app && flutter test    # state parsing, smoothing, join screen
```

## Protocol

Client to server:

```json
{"t":"join","name":"Hero"}
{"t":"input","x":0,"y":-1}
```

Server to client:

```json
{"t":"welcome","id":"p1","best":0,"maxPlayers":4}
{"t":"state","tick":12,"wave":2,"phase":"fighting","timer":0,"best":1,
 "players":[{"id":"p1","name":"Hero","x":500,"y":300,"hp":86,"maxHp":100,"dead":false,"kills":4}],
 "enemies":[{"id":"e9","x":30,"y":120,"hp":20,"maxHp":30}]}
```

The server ticks at 20 Hz and broadcasts a full snapshot every 100 ms. `phase` is `intermission`, `fighting` or `over`. A run restarts automatically 4 seconds after a full wipe.

## Deliberately not included

Accounts, database persistence, multiple rooms, matchmaking, chat, sound, real art, reconnection, client-side prediction, deployment. One server process = one room. The best wave is lost when the server restarts.
