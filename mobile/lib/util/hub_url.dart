/// Normalize / extract Music Hub server URL from free text or QR payload.
String? extractHubUrl(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;

  // QR might contain pure URL or text with URL inside
  final urlMatch = RegExp(
    r'https?://[^\s<>"{}|\\^`\[\]]+',
    caseSensitive: false,
  ).firstMatch(s);
  if (urlMatch != null) {
    s = urlMatch.group(0)!;
  }

  // host:port without scheme
  if (!s.startsWith('http://') && !s.startsWith('https://')) {
    // e.g. 192.168.0.8:8787 or 192.168.0.8
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}(:\d+)?$').hasMatch(s) ||
        RegExp(r'^[a-zA-Z0-9.-]+(:\d+)?$').hasMatch(s)) {
      s = 'http://$s';
    } else {
      return null;
    }
  }

  // strip trailing slash
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }

  final uri = Uri.tryParse(s);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;

  // default port 8787 if missing and looks like LAN hub
  if (!uri.hasPort) {
    s = '${uri.scheme}://${uri.host}:8787';
  }

  return s;
}

bool looksLikeHubUrl(String raw) => extractHubUrl(raw) != null;
