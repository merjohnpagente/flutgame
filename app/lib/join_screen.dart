import 'package:flutter/material.dart';

import 'game_screen.dart';
import 'glass.dart';

const _defaultServer = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'ws://localhost:8080',
);

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _name = TextEditingController(text: 'Hero');
  final _server = TextEditingController(text: _defaultServer);
  bool _online = false;

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    super.dispose();
  }

  void _join() {
    final name = _name.text.trim();
    final server = _server.text.trim();
    if (_online && server.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          name: name.isEmpty ? 'Hero' : name,
          serverUrl: _online ? server : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [Color(0xFF211C2E), Color(0xFF0D0D14)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.9, -0.8),
                  radius: 0.7,
                  colors: [Color(0x33E0A94A), Color(0x00E0A94A)],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.9, 0.9),
                  radius: 0.8,
                  colors: [Color(0x335B8DEF), Color(0x00000000)],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: GlassPanel(
                      padding: const EdgeInsets.all(24),
                      radius: 28,
                      blur: 18,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.castle_outlined,
                            size: 56,
                            color: colors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'DUNGEON CO-OP',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Solo offline, or co-op on your Wi-Fi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('Offline'),
                                  icon: Icon(Icons.phone_android),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('Online'),
                                  icon: Icon(Icons.wifi),
                                ),
                              ],
                              selected: {_online},
                              showSelectedIcon: false,
                              onSelectionChanged: (selection) =>
                                  setState(() => _online = selection.first),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _online
                                ? 'Up to 4 players on the same Wi-Fi.'
                                : 'Solo run. No internet or server needed.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _name,
                            textInputAction: TextInputAction.next,
                            maxLength: 16,
                            decoration: const InputDecoration(
                              labelText: 'Hero name',
                              prefixIcon: Icon(Icons.person_outline),
                              counterText: '',
                            ),
                          ),
                          if (_online) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: _server,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.go,
                              onSubmitted: (_) => _join(),
                              decoration: const InputDecoration(
                                labelText: 'Server',
                                helperText: 'ws://<your-lan-ip>:8080 on a phone',
                                prefixIcon: Icon(Icons.dns_outlined),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _join,
                            icon: Icon(
                              _online ? Icons.login : Icons.play_arrow,
                            ),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                _online ? 'Enter the dungeon' : 'Play offline',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Move with WASD, arrows, or the joystick.\nAttacks fire automatically at the nearest slime.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
