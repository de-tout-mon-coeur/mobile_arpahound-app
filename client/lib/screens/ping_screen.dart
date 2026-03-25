import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../widgets/terminal_card.dart';

class PingScreen extends StatefulWidget {
  final String host;
  const PingScreen({super.key, required this.host});

  @override
  State<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends State<PingScreen> {
  final List<double> _history = [];
  static const int _maxHistory = 30;
  static const double _timeoutVal = 9999;

  Timer? _timer;
  bool _running = false;
  double? _last;
  bool _lastTimeout = false;

  double get _min => _goodSamples.isEmpty
      ? 0
      : _goodSamples.reduce((a, b) => a < b ? a : b);
  double get _max => _goodSamples.isEmpty
      ? 0
      : _goodSamples.reduce((a, b) => a > b ? a : b);
  double get _avg => _goodSamples.isEmpty
      ? 0
      : _goodSamples.reduce((a, b) => a + b) / _goodSamples.length;
  int get _lost =>
      _history.where((v) => v >= _timeoutVal).length;

  List<double> get _goodSamples =>
      _history.where((v) => v < _timeoutVal).toList();

  void _startStop() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      setState(() => _running = true);
      _doPing();
      _timer = Timer.periodic(
          const Duration(seconds: 2), (_) => _doPing());
    }
  }

  Future<void> _doPing() async {
    if (widget.host.isEmpty) return;
    final ms = await ApiService(widget.host).ping();
    if (!mounted) return;
    setState(() {
      if (ms != null) {
        _last = ms;
        _lastTimeout = false;
        _history.add(ms);
      } else {
        _last = null;
        _lastTimeout = true;
        _history.add(_timeoutVal);
      }
      if (_history.length > _maxHistory) _history.removeAt(0);
    });
  }

  List<FlSpot> get _spots => List.generate(
        _history.length,
        (i) => FlSpot(i.toDouble(),
            _history[i].clamp(0, 500).toDouble()),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildStatus(),
          const SizedBox(height: 16),
          _buildChart(),
          const SizedBox(height: 16),
          _buildStats(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _startStop,
              style: ElevatedButton.styleFrom(
                backgroundColor: _running
                    ? const Color(0xFF1A0000)
                    : AppTheme.greenDark,
                foregroundColor:
                    _running ? AppTheme.red : AppTheme.green,
                side: BorderSide(
                    color: _running
                        ? AppTheme.red
                        : AppTheme.green),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
              ),
              child: Text(
                _running ? '■  STOP' : '>  START PING',
                style: const TextStyle(
                    letterSpacing: 3, fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    return TerminalCard(
      child: Row(
        children: [
          // Blink dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _running
                  ? (_lastTimeout ? AppTheme.red : AppTheme.green)
                  : AppTheme.textDim,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _running
                ? (_lastTimeout ? '> TIMEOUT' : '> PROBING')
                : '> IDLE',
            style: TextStyle(
              fontFamily: 'monospace',
              color: _running
                  ? (_lastTimeout
                      ? AppTheme.red
                      : AppTheme.green)
                  : AppTheme.textDim,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          if (_last != null && !_lastTimeout)
            Text(
              '${_last!.toStringAsFixed(1)} ms',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.cyan,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            )
          else if (_lastTimeout)
            const Text('TIMEOUT',
                style: TextStyle(
                    fontFamily: 'monospace',
                    color: AppTheme.red,
                    fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return TerminalCard(
      title: 'LATENCY HISTORY',
      child: SizedBox(
        height: 160,
        child: _history.isEmpty
            ? const Center(
                child: Text('[ no data ]',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        color: AppTheme.textDim,
                        fontSize: 12)),
              )
            : LineChart(
                LineChartData(
                  backgroundColor: AppTheme.bg,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppTheme.border,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text(
                          '${v.round()}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: AppTheme.textDim,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(
                      left:
                          BorderSide(color: AppTheme.border),
                      bottom:
                          BorderSide(color: AppTheme.border),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _spots,
                      isCurved: true,
                      color: AppTheme.green,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color:
                            AppTheme.green.withOpacity(0.06),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: _max > 0
                      ? (_max * 1.4).ceilToDouble()
                      : 100,
                ),
              ),
      ),
    );
  }

  Widget _buildStats() {
    return TerminalCard(
      title: 'STATS',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('MIN', _goodSamples.isEmpty ? '---' : '${_min.toStringAsFixed(1)}ms'),
          _stat('AVG', _goodSamples.isEmpty ? '---' : '${_avg.toStringAsFixed(1)}ms'),
          _stat('MAX', _goodSamples.isEmpty ? '---' : '${_max.toStringAsFixed(1)}ms'),
          _stat('LOSS',
              '${_history.isEmpty ? 0 : (_lost / _history.length * 100).round()}%',
              color: _lost > 0 ? AppTheme.red : AppTheme.green),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {Color? color}) =>
      Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppTheme.textDim,
                  fontSize: 10,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                fontFamily: 'monospace',
                color: color ?? AppTheme.green,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              )),
        ],
      );

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
