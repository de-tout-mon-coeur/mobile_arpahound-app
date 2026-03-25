import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/settings_service.dart';
import '../services/ws_service.dart';
import 'traffic_screen.dart';
import 'speedtest_screen.dart';
import 'ping_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  String _host = '';
  final _ws = WsService();
  final _hostCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAndConnect();
  }

  Future<void> _loadAndConnect() async {
    final host = await SettingsService.getHost();
    setState(() => _host = host);
    _ws.connect(host);
  }

  void _showSettings() {
    _hostCtrl.text = _host;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          '[ SERVER CONFIG ]',
          style: TextStyle(
            fontFamily: 'monospace',
            color: AppTheme.green,
            fontSize: 13,
            letterSpacing: 2,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'host:port',
              style: TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.textDim,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hostCtrl,
              style: const TextStyle(
                  fontFamily: 'monospace', color: AppTheme.green),
              decoration: const InputDecoration(
                hintText: '192.168.1.100:8000',
                isDense: true,
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(
                    fontFamily: 'monospace', color: AppTheme.textDim)),
          ),
          ElevatedButton(
            onPressed: () async {
              final host = _hostCtrl.text.trim();
              if (host.isNotEmpty) {
                await SettingsService.setHost(host);
                _ws.disconnect();
                setState(() => _host = host);
                _ws.connect(host);
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('CONNECT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ARPAHOUND'),
        actions: [
          // WS connection indicator
          StreamBuilder<WsState>(
            stream: _ws.state,
            builder: (_, snap) {
              final s = snap.data ?? WsState.disconnected;
              final color = s == WsState.connected
                  ? AppTheme.green
                  : s == WsState.connecting
                      ? AppTheme.amber
                      : AppTheme.red;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.circle, color: color, size: 10),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_ethernet, size: 20),
            onPressed: _showSettings,
            tooltip: 'Server',
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          TrafficScreen(wsService: _ws),
          SpeedtestScreen(host: _host),
          PingScreen(host: _host),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.network_check, size: 20),
              label: 'TRAFFIC',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.speed, size: 20),
              label: 'SPEED',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timeline, size: 20),
              label: 'PING',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ws.dispose();
    _hostCtrl.dispose();
    super.dispose();
  }
}
