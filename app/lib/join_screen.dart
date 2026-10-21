import 'package:flutter/material.dart';

import 'game_screen.dart';

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

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    super.dispose();
  }

  void _join() {
    final name = _name.text.trim();
    final server = _server.text.trim();
    if (server.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          name: name.isEmpty ? 'Hero' : name,
          serverUrl: server,
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.castle_outlined, size: 56, color: colors.primary),
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
                      'Four heroes. Endless waves. One room.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 32),
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
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _join,
                      icon: const Icon(Icons.login),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Enter the dungeon'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Move with WASD, arrows, or the joystick.\nAttacks fire automatically at the nearest slime.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
