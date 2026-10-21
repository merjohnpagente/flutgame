import 'dart:ui';

import 'package:flutter/material.dart';

class Joystick extends StatefulWidget {
  const Joystick({super.key, required this.onChanged});

  final ValueChanged<Offset> onChanged;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  static const double _size = 132;
  static const double _radius = 44;
  static const double _deadZone = 0.12;

  Offset _input = Offset.zero;

  void _update(Offset local) {
    const center = Offset(_size / 2, _size / 2);
    final delta = local - center;
    final distance = delta.distance;
    if (distance < _size * 0.06) {
      _set(Offset.zero);
      return;
    }
    final normalized = distance > _radius ? delta * (_radius / distance) : delta;
    final value = normalized / _radius;
    _set(value.distance < _deadZone ? Offset.zero : value);
  }

  void _set(Offset value) {
    setState(() => _input = value);
    widget.onChanged(value);
  }

  void _reset() => _set(Offset.zero);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Movement joystick',
      child: GestureDetector(
        onPanStart: (details) => _update(details.localPosition),
        onPanUpdate: (details) => _update(details.localPosition),
        onPanEnd: (_) => _reset(),
        onPanCancel: _reset,
        child: SizedBox(
          width: _size,
          height: _size,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x24FFFFFF), Color(0x08FFFFFF)],
                  ),
                  border: Border.all(
                    color: const Color(0x3DFFFFFF),
                    width: 1.5,
                  ),
                ),
                child: CustomPaint(painter: _JoystickPainter(_input)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter(this.input);

  final Offset input;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, 3, Paint()..color = const Color(0x55FFFFFF));

    final knob = center + input * _JoystickState._radius;
    canvas.drawCircle(knob, 25, Paint()..color = const Color(0x33E0A94A));
    canvas.drawCircle(knob, 20, Paint()..color = const Color(0xE6E0A94A));
    canvas.drawCircle(
      knob,
      20,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xCCFFFFFF),
    );
    canvas.drawCircle(
      knob + const Offset(-6, -6),
      5,
      Paint()..color = const Color(0x66FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_JoystickPainter oldDelegate) => oldDelegate.input != input;
}
