import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../widgets/terminal_card.dart';

enum _TestState { idle, download, upload, done }

class SpeedtestScreen extends StatefulWidget {
  final String host;
  const SpeedtestScreen({super.key, required this.host});

  @override
  State<SpeedtestScreen> createState() => _SpeedtestScreenState();
}

class _SpeedtestScreenState extends State<SpeedtestScreen>
    with SingleTickerProviderStateMixin {
  _TestState _state = _TestState.idle;
  double _currentSpeed = 0;
  double _dlResult = 0;
  double _ulResult = 0;
  String? _error;

  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  Future<void> _run() async {
    if (widget.host.isEmpty) {
      setState(() => _error = 'Set server address first');
      return;
    }
    final api = ApiService(widget.host);

    setState(() {
      _state = _TestState.download;
      _currentSpeed = 0;
      _dlResult = 0;
      _ulResult = 0;
      _error = null;
    });

    final dl = await api.measureDownload(
      onProgress: (mbps) {
        if (mounted) setState(() => _currentSpeed = mbps);
      },
    );

    setState(() {
      _state = _TestState.upload;
      _dlResult = dl;
      // Keep _currentSpeed at last download value so the gauge
      // doesn't snap to 0 before the first upload progress arrives.
    });

    final ul = await api.measureUpload(
      onProgress: (mbps) {
        if (mounted) setState(() => _currentSpeed = mbps);
      },
    );

    setState(() {
      _state = _TestState.done;
      _ulResult = ul;
      _currentSpeed = 0;
    });
  }

  bool get _running =>
      _state == _TestState.download || _state == _TestState.upload;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildGauge(),
          const SizedBox(height: 20),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppTheme.red,
                      fontSize: 12)),
            ),

          if (!_running)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _run,
                child: Text(
                  _state == _TestState.done
                      ? '> RUN AGAIN'
                      : '> START TEST',
                  style: const TextStyle(
                      letterSpacing: 3, fontSize: 14),
                ),
              ),
            ),

          if (_state == _TestState.done || _dlResult > 0) ...[
            const SizedBox(height: 20),
            _buildResults(),
          ],
        ],
      ),
    );
  }

  Widget _buildGauge() {
    final label = switch (_state) {
      _TestState.download => 'DOWNLOAD',
      _TestState.upload => 'UPLOAD',
      _TestState.done => 'COMPLETE',
      _TestState.idle => 'READY',
    };

    return TerminalCard(
      title: 'SPEEDTEST',
      child: Column(
        children: [
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: _currentSpeed),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (_, animSpeed, child) => SizedBox(
              width: 220,
              height: 220,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => CustomPaint(
                  painter: _GaugePainter(
                    speed: animSpeed,
                    running: _running,
                    pulseValue: _running ? _pulse.value : 1.0,
                  ),
                  child: child,
                ),
              ),
            ),
            child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) {
                        final opacity = _running
                            ? 0.55 + _pulse.value * 0.45
                            : 1.0;
                        final speed = _state == _TestState.idle
                            ? '--'
                            : _currentSpeed.toStringAsFixed(1);
                        return Text(
                          speed,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 40,
                            color: AppTheme.green
                                .withOpacity(opacity),
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    const Text(
                      'Mbps',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppTheme.textDim,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: AppTheme.textDim,
              fontSize: 12,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return TerminalCard(
      title: 'RESULTS',
      child: Column(
        children: [
          _row('DOWNLOAD', _dlResult, Icons.download_rounded,
              AppTheme.green),
          const SizedBox(height: 14),
          _row('UPLOAD', _ulResult, Icons.upload_rounded,
              AppTheme.cyan),
        ],
      ),
    );
  }

  Widget _row(String label, double mbps, IconData icon, Color c) =>
      Row(
        children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppTheme.textDim,
                  fontSize: 12,
                  letterSpacing: 2)),
          const Spacer(),
          Text(
            mbps > 0 ? '${mbps.toStringAsFixed(2)} Mbps' : '---',
            style: TextStyle(
              fontFamily: 'monospace',
              color: c,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }
}

// ── Custom arc gauge ──────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double speed;
  final bool running;
  final double pulseValue;

  // Visual max = 1000 Mbps
  static const double _maxSpeed = 1000;

  _GaugePainter({required this.speed, required this.running, this.pulseValue = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;

    const startAngle = pi * 0.75;
    const sweep = pi * 1.5;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      Paint()
        ..color = const Color(0xFF001A07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    // Speed arc
    final frac = (speed / _maxSpeed).clamp(0.0, 1.0);
    if (frac > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep * frac,
        false,
        Paint()
          ..color = running
              ? AppTheme.green.withOpacity(0.55 + pulseValue * 0.45)
              : const Color(0xFF006B1C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round,
      );
    }

    // Tick marks
    final tickPaint = Paint()
      ..color = const Color(0xFF003300)
      ..strokeWidth = 1.5;
    for (int i = 0; i <= 10; i++) {
      final a = startAngle + (sweep * i / 10);
      canvas.drawLine(
        center + Offset(cos(a), sin(a)) * (radius - 20),
        center + Offset(cos(a), sin(a)) * (radius - 6),
        tickPaint,
      );
    }

    // Glow dot at tip
    if (frac > 0) {
      final tipAngle = startAngle + sweep * frac;
      final tipPt =
          center + Offset(cos(tipAngle), sin(tipAngle)) * radius;
      canvas.drawCircle(
        tipPt,
        5,
        Paint()..color = AppTheme.green,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.speed != speed || old.running != running || old.pulseValue != pulseValue;
}
