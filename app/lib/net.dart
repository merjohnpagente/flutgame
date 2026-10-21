import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'model.dart';

class GameConnection {
  GameConnection(this.url);

  final String url;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;

  Future<void> connect({
    required String name,
    required void Function(String id, int best) onWelcome,
    required void Function(Snapshot snapshot) onState,
    required void Function(String message) onError,
    required void Function() onClosed,
  }) async {
    final uri = Uri.tryParse(_normalize(url));
    if (uri == null ||
        (uri.scheme != 'ws' && uri.scheme != 'wss') ||
        uri.host.isEmpty) {
      throw const FormatException('Server must be a ws:// or wss:// address');
    }

    final channel = WebSocketChannel.connect(uri);
    try {
      await channel.ready.timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException('Could not reach $url'),
      );
    } catch (_) {
      try {
        await channel.sink.close();
      } catch (_) {
        // Socket already gone.
      }
      rethrow;
    }
    if (_closed) {
      await channel.sink.close();
      return;
    }
    _channel = channel;

    _subscription = channel.stream.listen(
      (event) {
        if (event is! String) return;
        Object? decoded;
        try {
          decoded = jsonDecode(event);
        } catch (_) {
          return;
        }
        if (decoded is! Map<String, dynamic>) return;

        final type = decoded['t'];
        if (type == 'welcome') {
          onWelcome(
            decoded['id'] as String? ?? '',
            (decoded['best'] as num?)?.toInt() ?? 0,
          );
        } else if (type == 'state') {
          onState(Snapshot.fromJson(decoded));
        } else if (type == 'error') {
          onError(decoded['message'] as String? ?? 'Server error');
        }
      },
      onError: (Object error) {
        if (!_closed) onError('Connection error: $error');
      },
      onDone: () {
        if (!_closed) onClosed();
      },
      cancelOnError: false,
    );

    _channel!.sink.add(jsonEncode({'t': 'join', 'name': name}));
  }

  void sendInput(double x, double y) {
    final channel = _channel;
    if (channel == null || _closed) return;
    try {
      channel.sink.add(jsonEncode({
        't': 'input',
        'x': double.parse(x.toStringAsFixed(3)),
        'y': double.parse(y.toStringAsFixed(3)),
      }));
    } catch (_) {
      // Socket closed mid-frame; the disconnect handler owns the UI.
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {
      // The socket may already be gone; nothing left to clean up.
    }
    _channel = null;
  }

  static String _normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.contains('://')) return trimmed;
    return 'ws://$trimmed';
  }
}
