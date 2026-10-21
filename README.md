# Dungeon Co-op

A small dungeon game with a glassmorphism HUD: play solo offline, or share one arena with up to 4 players on your Wi-Fi. Fight waves of slimes and try to beat your best wave. Offline mode runs entirely in the app — no server or internet needed. Online co-op uses an optional Node server that owns movement, enemies, damage and wave state.

```
server/   optional Node + ws authoritative co-op room
app/      Flutter client (Canvas arena, sprite characters, glass HUD)
  assets/characters/  hero variants and slime sprites
```

## Play offline

The app defaults to **Offline**: open it, enter a name and tap **Play offline**. Nothing else to install or run.

## Run the app

Requires Flutter 3.22 or newer.

```sh
cd app
flutter create --empty --platforms=android,linux,windows --project-name dungeon_coop .
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter run -d linux      # or: -d windows / -d macos (add macos to --platforms)
```

`flutter create` only fills in the platform folders; it does not overwrite `lib/` or `pubspec.yaml` unless you pass `--overwrite`. The two generators write the Android launcher icon and splash screen, so run them after the platform folders exist.

## Build the APK

No local Flutter needed: `.github/workflows/build.yml` tests the server and app, generates the icon/splash, and builds a release APK on GitHub Actions. Push the repo and open the **Actions** tab to download the `dungeon-coop-apk` artifact. The workflow adds the Android internet permission automatically so online mode works.

## Optional: online co-op

Run the server on a computer that is on the same Wi-Fi as the phone:

```sh
cd server
npm install
npm start
```

It listens on `ws://0.0.0.0:8080` (override with `PORT=9000 npm start`). Open the port on your firewall if a phone will connect. In the app choose **Online** and enter `ws://<your-computer-lan-ip>:8080`.

The server address defaults to `ws://localhost:8080` for desktop. Set it at build time or edit the field on the join screen:

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

Debug builds already have it via Flutter's debug manifest. Playing across different networks needs the server deployed with TLS (`wss://`); that hosting is not included.

## Controls

- Move: WASD / arrow keys, or drag the on-screen joystick.
- Attack: automatic at the nearest slime in range.
- Phones run in landscape; online supports 4 players maximum.
- Offline is a solo run: death ends the run and a new one starts in 4 seconds. Your best wave is kept while you stay on the game screen.

## Tests

```sh
cd server && npm test     # game logic + two real WebSocket clients
cd app && flutter test    # offline simulation, offline game screen, state parsing, join screen
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

The server ticks at 20 Hz and broadcasts a full snapshot every 100 ms. `phase` is `intermission`, `fighting` or `over`. An online run restarts automatically 4 seconds after a full wipe. Offline mode uses the same rules locally.

## Deliberately not included

Accounts, database persistence, multiple rooms, matchmaking, chat, sound, real art, reconnection, client-side prediction, server deployment. Online is one server process = one room, and the best wave is lost when the server restarts. Offline is solo only and its best wave is lost when you leave the run.
