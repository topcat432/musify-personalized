import 'package:http/http.dart' as http;

/// Validate with playback request semantics: some working media URLs reject HEAD.
/// Close the response as soon as headers arrive, including when Range is ignored.
Future<bool> validateStreamUrl(
  String url, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 10),
  Map<String, String> headers = const {},
}) async {
  final probe = client ?? http.Client();
  try {
    final request = http.Request('GET', Uri.parse(url))
      ..headers.addAll(headers)
      ..headers['Range'] = 'bytes=0-0';
    final response = await probe.send(request).timeout(timeout);
    return response.statusCode == 200 || response.statusCode == 206;
  } catch (_) {
    return false;
  } finally {
    probe.close();
  }
}
