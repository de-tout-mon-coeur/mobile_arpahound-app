class Packet {
  final double timestamp;
  final int length;
  final String proto;
  final String src;
  final String dst;

  const Packet({
    required this.timestamp,
    required this.length,
    required this.proto,
    required this.src,
    required this.dst,
  });

  factory Packet.fromJson(Map<String, dynamic> json) {
    return Packet(
      timestamp: (json['ts'] as num).toDouble(),
      length: json['len'] as int,
      proto: json['proto'] as String? ?? 'Other',
      src: json['src'] as String? ?? '-',
      dst: json['dst'] as String? ?? '-',
    );
  }

  /// Short protocol label for display
  String get protoShort {
    if (proto.startsWith('TCP')) return 'TCP';
    if (proto.startsWith('UDP')) return 'UDP';
    return proto;
  }

  /// Monotonic seconds → "NNNNN.mmm"
  String get timeDisplay {
    final intPart = (timestamp.toInt() % 100000).toString().padLeft(5, '0');
    final fracPart =
        ((timestamp % 1) * 1000).round().toString().padLeft(3, '0');
    return '$intPart.$fracPart';
  }
}
