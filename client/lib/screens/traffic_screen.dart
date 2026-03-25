import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/packet.dart';
import '../services/ws_service.dart';

class TrafficScreen extends StatefulWidget {
  final WsService wsService;
  const TrafficScreen({super.key, required this.wsService});

  @override
  State<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends State<TrafficScreen> {
  final List<Packet> _packets = [];
  bool _autoScroll = true;
  String _filter = '';
  static const int _maxPackets = 200;

  @override
  void initState() {
    super.initState();
    widget.wsService.packets.listen((pkt) {
      if (!mounted || !_autoScroll) return;
      setState(() {
        _packets.insert(0, pkt);
        if (_packets.length > _maxPackets) _packets.removeLast();
      });
    });
  }

  Color _protoColor(String proto) {
    if (proto.startsWith('TCP')) return AppTheme.green;
    if (proto.startsWith('UDP')) return AppTheme.cyan;
    if (proto == 'ARP') return AppTheme.amber;
    return AppTheme.textDim;
  }

  List<Packet> get _filtered {
    if (_filter.isEmpty) return _packets;
    final q = _filter.toLowerCase();
    return _packets
        .where((p) =>
            p.proto.toLowerCase().contains(q) ||
            p.src.contains(_filter) ||
            p.dst.contains(_filter))
        .toList();
  }

  String _trunc(String s, int max) =>
      s.length > max ? '${s.substring(0, max - 1)}…' : s;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      children: [
        // ── Toolbar ────────────────────────────────────────────
        Container(
          color: AppTheme.surface,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Text(
                '${_packets.length} pkts',
                style: const TextStyle(
                    fontFamily: 'monospace',
                    color: AppTheme.textDim,
                    fontSize: 11),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    setState(() => _autoScroll = !_autoScroll),
                child: Text(
                  _autoScroll ? '▼ LIVE' : '■ PAUSED',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _autoScroll
                        ? AppTheme.green
                        : AppTheme.amber,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => setState(() => _packets.clear()),
                child: const Text('CLR',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        color: AppTheme.red,
                        fontSize: 11)),
              ),
            ],
          ),
        ),

        // ── Filter ─────────────────────────────────────────────
        Container(
          color: AppTheme.bg,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            onChanged: (v) => setState(() => _filter = v),
            style: const TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.green,
                fontSize: 12),
            decoration: const InputDecoration(
              hintText: '> filter  ip / proto',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              prefixIcon:
                  Icon(Icons.search, color: AppTheme.textDim, size: 16),
            ),
          ),
        ),

        // ── Column headers ─────────────────────────────────────
        Container(
          color: AppTheme.greenDark,
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: const Row(
            children: [
              SizedBox(
                  width: 72, child: Text('TIME', style: _hdr)),
              SizedBox(
                  width: 56, child: Text('PROTO', style: _hdr)),
              Expanded(child: Text('SRC → DST', style: _hdr)),
              SizedBox(
                  width: 50,
                  child: Text('B', style: _hdr,
                      textAlign: TextAlign.right)),
            ],
          ),
        ),

        // ── Packet list ────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _packets.isEmpty
                        ? '[ waiting for packets... ]'
                        : '[ no matches ]',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppTheme.textDim,
                        fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    final c = _protoColor(p.proto);
                    return Container(
                      color: i.isEven
                          ? AppTheme.bg
                          : AppTheme.surface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(p.timeDisplay,
                                style: _cell(
                                    AppTheme.textDim)),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(p.protoShort,
                                style: _cell(c,
                                    bold: true)),
                          ),
                          Expanded(
                            child: Text(
                              '${_trunc(p.src, 18)}→${_trunc(p.dst, 18)}',
                              style:
                                  _cell(c.withOpacity(0.8)),
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: Text('${p.length}',
                                style: _cell(
                                    AppTheme.textDim),
                                textAlign:
                                    TextAlign.right),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static const TextStyle _hdr = TextStyle(
    fontFamily: 'monospace',
    color: AppTheme.green,
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
  );

  static TextStyle _cell(Color c, {bool bold = false}) => TextStyle(
        fontFamily: 'monospace',
        color: c,
        fontSize: 10,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      );
}
