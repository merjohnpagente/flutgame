import 'dart:math' as math;
import 'dart:ui' as ui;

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
    this.sprites = const {},
  });

  final Snapshot snapshot;
  final Map<String, Offset> positions;
  final String? selfId;
  final Map<String, double> hitFlash;
  final double hurt;
  final Map<String, ui.Image> sprites;

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
      final sprite = sprites['slime'];
      if (sprite == null) {
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
      } else {
        _drawSprite(canvas, sprite, position, 38);
        if (flash > 0) {
          canvas.drawCircle(
            position,
            20,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = Colors.white
                  .withAlpha((flash / 0.18 * 220).clamp(0, 255).round()),
          );
        }
      }
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
      final sprite = sprites[_heroSprite(player.id)];
      if (sprite == null) {
        final color = _playerColor(player.id, player.dead);
        canvas.drawCircle(position, 16, Paint()..color = color);
        canvas.drawCircle(
          position + const Offset(0, -4),
          6,
          Paint()..color = const Color(0x44000000),
        );
      } else {
        _drawSprite(canvas, sprite, position, 46, dead: player.dead);
      }
      if (player.id == selfId) {
        canvas.drawCircle(
          position,
          25,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xCCFFFFFF),
        );
      }

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

  void _drawSprite(
    Canvas canvas,
    ui.Image image,
    Offset center,
    double size, {
    bool dead = false,
  }) {
    final paint = Paint()..filterQuality = ui.FilterQuality.medium;
    if (dead) {
      paint.colorFilter = ColorFilter.mode(
        const Color(0xFF555566),
        BlendMode.srcATop,
      );
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: center, width: size, height: size),
      paint,
    );
  }

  String _heroSprite(String id) {
    const heroes = ['hero_gold', 'hero_blue', 'hero_green', 'hero_purple'];
    if (id == selfId) return heroes.first;
    return heroes[id.hashCode.abs() % heroes.length];
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
