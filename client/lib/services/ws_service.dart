import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/packet.dart';

enum WsState { disconnected, connecting, connected }

class WsService {
  WebSocketChannel? _channel;
  String _host = '';
  bool _shouldConnect = false;
  Timer? _reconnectTimer;

  final _packetCtrl = StreamController<Packet>.broadcast();
  final _stateCtrl = StreamController<WsState>.broadcast();

  Stream<Packet> get packets => _packetCtrl.stream;
  Stream<WsState> get state => _stateCtrl.stream;

  void connect(String host) {
    _host = host;
    _shouldConnect = true;
    _stateCtrl.add(WsState.connecting);
    _doConnect();
  }

  void _doConnect() {
    if (!_shouldConnect) return;
    try {
      final uri = Uri.parse('ws://$_host/ws');
      _channel = WebSocketChannel.connect(uri);
      _stateCtrl.add(WsState.connected);
      _channel!.stream.listen(
        (data) {
          try {
            final json =
                jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] == 'packet') {
              _packetCtrl.add(Packet.fromJson(json));
            }
          } catch (_) {}
        },
        onDone: () {
          _stateCtrl.add(WsState.disconnected);
          _scheduleReconnect();
        },
        onError: (_) {
          _stateCtrl.add(WsState.disconnected);
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _stateCtrl.add(WsState.disconnected);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldConnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer =
        Timer(const Duration(seconds: 3), _doConnect);
  }

  void disconnect() {
    _shouldConnect = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _stateCtrl.add(WsState.disconnected);
  }

  void dispose() {
    disconnect();
    _packetCtrl.close();
    _stateCtrl.close();
  }
}
