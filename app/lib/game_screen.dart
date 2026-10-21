import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'arena_painter.dart';
import 'joystick.dart';
import 'model.dart';
import 'net.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.name, required this.serverUrl});

  final String name;
  final String serverUrl;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final GameConnection _connection;
  late final Ticker _ticker;

  final Map<String, Offset> _positions = {};
  final Map<String, double> _hitFlash = {};
  final Set<LogicalKeyboardKey> _keys = {};

  Snapshot? _snapshot;
  String? _selfId;
  String? _error;
  Offset _stick = Offset.zero;
  double _hurt = 0;
  Duration _lastFrame = Duration.zero;
  Timer? _inputTimer;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _connection = GameConnection(widget.serverUrl);
    _ticker = createTicker(_onFrame)..start();
    _inputTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _sendInput(),
    );
    _timeout = Timer(const Duration(seconds: 7), () {
      if (!mounted || _snapshot != null || _error != null) return;
      setState(() => _error =
          'No state from the server. Check the address and that the server is running.');
      unawaited(_connection.close());
    });
    unawaited(_connect());
  }

  Future<void> _connect() async {
    try {
      await _connection.connect(
        name: widget.name,
        onWelcome: (id, _) {
          if (!mounted) return;
          setState(() => _selfId = id);
        },
        onState: _apply,
        onError: (message) {
          if (!mounted) return;
          setState(() => _error = message);
          unawaited(_connection.close());
        },
        onClosed: () {
          if (!mounted) return;
          setState(() => _error ??= 'Disconnected from the server');
          unawaited(_connection.close());
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendly(error));
    }
  }

  void _apply(Snapshot snapshot) {
    if (!mounted) return;
    final previous = _snapshot;
    if (previous != null) {
      final oldHp = {for (final enemy in previous.enemies) enemy.id: enemy.hp};
      for (final enemy in snapshot.enemies) {
        final before = oldHp[enemy.id];
        if (before != null && enemy.hp < before) {
          _hitFlash[enemy.id] = 0.18;
        }
      }
      final me = _find(previous);
      final now = _find(snapshot);
      if (me != null && now != null && now.hp < me.hp) _hurt = 0.4;
    }
    _snapshot = snapshot;
    _timeout?.cancel();
  }

  NetPlayer? _find(Snapshot? snapshot) {
    if (snapshot == null || _selfId == null) return null;
    for (final player in snapshot.players) {
      if (player.id == _selfId) return player;
    }
    return null;
  }

  void _onFrame(Duration elapsed) {
    final dt = _lastFrame == Duration.zero
        ? 0.016
        : (elapsed - _lastFrame).inMicroseconds / 1000000;
    _lastFrame = elapsed;
    final step = dt.clamp(0.0, 0.1).toDouble();
    final snapshot = _snapshot;
    if (snapshot == null) return;

    final seen = <String>{};
    for (final player in snapshot.players) {
      seen.add(player.id);
      _moveToward(player.id, Offset(player.x, player.y), step);
    }
    for (final enemy in snapshot.enemies) {
      seen.add(enemy.id);
      _moveToward(enemy.id, Offset(enemy.x, enemy.y), step);
    }
    _positions.removeWhere((id, _) => !seen.contains(id));

    _hitFlash.updateAll((id, value) => value - step);
    _hitFlash.removeWhere((id, value) => value <= 0);
    if (_hurt > 0) _hurt = math.max(0.0, _hurt - step);

    setState(() {});
  }

  void _moveToward(String id, Offset target, double step) {
    final current = _positions[id];
    _positions[id] = current == null
        ? target
        : Offset(
            smoothToward(current.dx, target.dx, step),
            smoothToward(current.dy, target.dy, step),
          );
  }

  Offset get _direction {
    var x = 0.0;
    var y = 0.0;
    if (_keys.contains(LogicalKeyboardKey.keyA) ||
        _keys.contains(LogicalKeyboardKey.arrowLeft)) {
      x -= 1;
    }
    if (_keys.contains(LogicalKeyboardKey.keyD) ||
        _keys.contains(LogicalKeyboardKey.arrowRight)) {
      x += 1;
    }
    if (_keys.contains(LogicalKeyboardKey.keyW) ||
        _keys.contains(LogicalKeyboardKey.arrowUp)) {
      y -= 1;
    }
    if (_keys.contains(LogicalKeyboardKey.keyS) ||
        _keys.contains(LogicalKeyboardKey.arrowDown)) {
      y += 1;
    }
    if (x == 0 && y == 0) return _stick;
    final value = Offset(x, y);
    return value.distance > 1 ? value / value.distance : value;
  }

  void _sendInput() {
    final direction = _direction;
    _connection.sendInput(direction.dx, direction.dy);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      _keys.add(event.logicalKey);
    } else if (event is KeyUpEvent) {
      _keys.remove(event.logicalKey);
    }
    return KeyEventResult.handled;
  }

  String _friendly(Object error) {
    var text = error.toString();
    for (final prefix in [
      'WebSocketException: ',
      'FormatException: ',
      'TimeoutException: ',
      'Exception: ',
    ]) {
      if (text.startsWith(prefix)) text = text.substring(prefix.length);
    }
    return text;
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _inputTimer?.cancel();
    _ticker.dispose();
    unawaited(_connection.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final me = _find(snapshot);

    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        onFocusChange: (hasFocus) {
          if (!hasFocus) _keys.clear();
        },
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF08080C)),
              if (snapshot != null)
                Positioned.fill(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: arenaWidth / arenaHeight,
                      child: CustomPaint(
                        painter: ArenaPainter(
                          snapshot: snapshot,
                          positions: _positions,
                          selfId: _selfId,
                          hitFlash: _hitFlash,
                          hurt: _hurt,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              if (snapshot != null)
                Positioned(top: 12, left: 16, child: _wavePanel(snapshot)),
              if (snapshot != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    children: [
                      if (me != null) _hpPanel(me),
                      const SizedBox(width: 8),
                      _leaveButton(),
                    ],
                  ),
                ),
              if (snapshot != null && _error == null)
                Positioned(
                  left: 20,
                  bottom: 16,
                  child: Joystick(onChanged: (value) => _stick = value),
                ),
              if (snapshot != null)
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: IgnorePointer(
                    child: Text(
                      'Drag / WASD to move · auto-attack',
                      style: TextStyle(
                        color: Colors.white.withAlpha(80),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              if (snapshot != null && snapshot.isOver) _overPanel(snapshot),
              if (snapshot == null && _error == null)
                _fullOverlay(
                  child: _panel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('Entering the dungeon…'),
                        const SizedBox(height: 6),
                        Text(
                          widget.serverUrl,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              if (_error != null)
                _fullOverlay(
                  child: _panel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          size: 36,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Connection problem',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to menu'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC111118),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: child,
    );
  }

  Widget _wavePanel(Snapshot snapshot) {
    final subtitle = switch (snapshot.phase) {
      'intermission' => 'Next wave in ${snapshot.timer.ceil()}s',
      'over' => 'Run over',
      _ => 'Slimes: ${snapshot.enemies.length}',
    };
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'WAVE ${snapshot.wave}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            'Best ${snapshot.best}',
            style: const TextStyle(color: Color(0xFFE0A94A), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _hpPanel(NetPlayer me) {
    final fraction =
        me.maxHp == 0 ? 0.0 : (me.hp / me.maxHp).clamp(0.0, 1.0).toDouble();
    final color =
        fraction > 0.35 ? const Color(0xFF6FD37A) : const Color(0xFFE05252);
    return _panel(
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              me.dead
                  ? 'DOWN · revives next wave'
                  : 'HP ${me.hp.round()} / ${me.maxHp.round()}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 7,
                backgroundColor: const Color(0xFF2A2A38),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leaveButton() {
    return IconButton(
      tooltip: 'Leave',
      onPressed: () => Navigator.of(context).pop(),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xCC111118),
      ),
      icon: const Icon(Icons.close),
    );
  }

  Widget _overPanel(Snapshot snapshot) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: _panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'RUN OVER',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: Color(0xFFE0A94A),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Reached wave ${snapshot.wave}'),
                const SizedBox(height: 4),
                Text(
                  'New run in ${snapshot.timer.ceil()}s',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fullOverlay({required Widget child}) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x99000000),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    );
  }
}
