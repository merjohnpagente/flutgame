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
          child: CustomPaint(painter: _JoystickPainter(_input)),
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
    final radius = size.width / 2 - 2;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0x55101018));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x55FFFFFF),
    );
    final knob = center + input * _JoystickState._radius;
    canvas.drawCircle(knob, 22, Paint()..color = const Color(0xCCE0A94A));
    canvas.drawCircle(
      knob,
      22,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xAAFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_JoystickPainter oldDelegate) => oldDelegate.input != input;
}
