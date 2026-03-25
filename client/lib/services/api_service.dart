import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  final String host;
  ApiService(this.host);

  String get baseUrl => 'http://$host';

  /// TCP connect latency to 8.8.8.8:53 measured server-side.
  Future<double?> ping() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/ping'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return double.tryParse(
            response.body.trim().replaceAll(' ms', ''));
      }
    } catch (_) {}
    return null;
  }

  /// Download 10 MB from server, report live speed via [onProgress].
  Future<double> measureDownload(
      {void Function(double mbps)? onProgress}) async {
    final client = http.Client();
    try {
      final request =
          http.Request('GET', Uri.parse('$baseUrl/download'));
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 60));

      int bytes = 0;
      DateTime? start;
      DateTime? end;
      DateTime lastProgress = DateTime.fromMillisecondsSinceEpoch(0);

      await for (final chunk in response.stream) {
        start ??= DateTime.now();
        bytes += chunk.length;
        end = DateTime.now(); // timestamp of last received byte
        final secs = end.difference(start).inMilliseconds / 1000.0;
        if (secs >= 0.1 &&
            end.difference(lastProgress).inMilliseconds >= 150 &&
            onProgress != null) {
          lastProgress = end;
          onProgress((bytes * 8) / (secs * 1e6));
        }
      }

      final totalSecs = (start == null || end == null)
          ? 0.0
          : end.difference(start).inMilliseconds / 1000.0;
      if (totalSecs == 0) return 0;
      return (bytes * 8) / (totalSecs * 1e6);
    } catch (_) {
      return 0;
    } finally {
      client.close();
    }
  }

  /// Upload 5 MB to server in 512 KB chunks, reports live speed via [onProgress].
  /// Each chunk is a separate POST request so we wait for the server ACK before
  /// measuring — this gives real network throughput instead of local buffer speed.
  Future<double> measureUpload(
      {void Function(double mbps)? onProgress}) async {
    const chunkSize = 32 * 1024; // 32 KB per request — frequent progress updates
    const totalChunks = 160;    // 5 MB total
    final chunk = Uint8List(chunkSize);

    final start = DateTime.now();
    int totalSent = 0;
    DateTime lastProgress = DateTime.fromMillisecondsSinceEpoch(0);

    for (int i = 0; i < totalChunks; i++) {
      try {
        await http
            .post(
              Uri.parse('$baseUrl/upload'),
              body: chunk,
              headers: {'Content-Type': 'application/octet-stream'},
            )
            .timeout(const Duration(seconds: 30));
      } catch (_) {
        break;
      }
      totalSent += chunkSize;
      final now = DateTime.now();
      final secs = now.difference(start).inMilliseconds / 1000.0;
      if (secs >= 0.1 &&
          now.difference(lastProgress).inMilliseconds >= 150 &&
          onProgress != null) {
        lastProgress = now;
        onProgress((totalSent * 8) / (secs * 1e6));
      }
    }

    final secs = DateTime.now().difference(start).inMilliseconds / 1000.0;
    if (secs == 0) return 0;
    return (totalSent * 8) / (secs * 1e6);
  }
}
