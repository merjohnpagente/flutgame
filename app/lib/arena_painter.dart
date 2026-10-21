import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'model.dart';

const double arenaWidth = 1000;
const double arenaHeight = 700;

class ArenaPainter extends CustomPainter {
  ArenaPainter({
    required this.snapshot,
    required this.positions,
    required this.selfId,
    required this.hitFlash,
    required this.hurt,
  });

  final Snapshot snapshot;
  final Map<String, Offset> positions;
  final String? selfId;
  final Map<String, double> hitFlash;
  final double hurt;

  @override
  void paint(Canvas canvas, Size size) {
    final scale =
        math.min(size.width / arenaWidth, size.height / arenaHeight);
    canvas.save();
    canvas.translate(
      (size.width - arenaWidth * scale) / 2,
      (size.height - arenaHeight * scale) / 2,
    );
    canvas.scale(scale);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, arenaWidth, arenaHeight),
      Paint()..color = const Color(0xFF15151F),
    );

    final grid = Paint()
      ..color = const Color(0xFF20202E)
      ..strokeWidth = 1;
    for (double x = 50; x < arenaWidth; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, arenaHeight), grid);
    }
    for (double y = 50; y < arenaHeight; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(arenaWidth, y), grid);
    }

    canvas.drawRect(
      const Rect.fromLTWH(3, 3, arenaWidth - 6, arenaHeight - 6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0xFF3A3A4E),
    );

    for (final enemy in snapshot.enemies) {
      final position = positions[enemy.id];
      if (position == null) continue;
      final flash = hitFlash[enemy.id] ?? 0;
      final color = Color.lerp(
        const Color(0xFFE05252),
        Colors.white,
        (flash / 0.18).clamp(0.0, 1.0).toDouble(),
      )!;
      canvas.drawCircle(position, 15, Paint()..color = color);
      canvas.drawCircle(
        position + const Offset(0, -4),
        5,
        Paint()..color = const Color(0x33000000),
      );
      if (enemy.hp < enemy.maxHp) {
        _bar(
          canvas,
          Offset(position.dx, position.dy - 26),
          enemy.hp / enemy.maxHp,
          30,
          const Color(0xFF9BD35A),
        );
      }
    }

    for (final player in snapshot.players) {
      final position = positions[player.id];
      if (position == null) continue;
      final color = _playerColor(player.id, player.dead);
      if (player.id == selfId) {
        canvas.drawCircle(
          position,
          21,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xCCFFFFFF),
        );
      }
      canvas.drawCircle(position, 16, Paint()..color = color);
      canvas.drawCircle(
        position + const Offset(0, -4),
        6,
        Paint()..color = const Color(0x44000000),
      );

      final label = TextPainter(
        text: TextSpan(
          text: player.dead ? '${player.name} · down' : player.name,
          style: TextStyle(
            color: player.dead ? const Color(0xFF888899) : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(position.dx - label.width / 2, position.dy - 48));

      _bar(
        canvas,
        Offset(position.dx, position.dy + 26),
        player.hp / player.maxHp,
        40,
        player.hp > player.maxHp * 0.35
            ? const Color(0xFF6FD37A)
            : const Color(0xFFE05252),
      );
    }

    canvas.restore();

    if (hurt > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(0xFFFF3333)
              .withAlpha((hurt / 0.4 * 70).clamp(0, 255).round()),
      );
    }
  }

  void _bar(
    Canvas canvas,
    Offset center,
    double fraction,
    double width,
    Color color,
  ) {
    final rect = Rect.fromCenter(center: center, width: width, height: 4);
    final radius = const Radius.circular(2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = const Color(0xAA000000),
    );
    final fill = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width * fraction.clamp(0.0, 1.0).toDouble(),
      rect.height,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(fill, radius), Paint()..color = color);
  }

  Color _playerColor(String id, bool dead) {
    if (dead) return const Color(0xFF555566);
    final hue = (id.hashCode.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.55, 0.6).toColor();
  }

  @override
  bool shouldRepaint(ArenaPainter oldDelegate) => true;
}
