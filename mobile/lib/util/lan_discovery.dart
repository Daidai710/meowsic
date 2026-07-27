import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// B5: scan local /24 subnet for Music Hub on [port].
Future<List<String>> discoverMusicHubs({int port = 8787, Duration timeout = const Duration(milliseconds: 350)}) async {
  final found = <String>[];
  String? localIp;
  try {
    for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false)) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (ip.startsWith('127.') || ip.startsWith('169.254.')) continue;
        localIp = ip;
        break;
      }
      if (localIp != null) break;
    }
  } catch (_) {}
  if (localIp == null) return found;

  final parts = localIp.split('.');
  if (parts.length != 4) return found;
  final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';

  final futures = <Future<void>>[];
  for (var i = 1; i <= 254; i++) {
    final host = '$prefix.$i';
    futures.add(() async {
      final url = 'http://$host:$port';
      try {
        final r = await http.get(Uri.parse('$url/api/status')).timeout(timeout);
        if (r.statusCode == 200 && r.body.contains('music-hub')) {
          found.add(url);
        } else if (r.statusCode == 200 && r.body.contains('song_count')) {
          found.add(url);
        }
      } catch (_) {}
    }());
  }
  await Future.wait(futures);
  found.sort();
  return found.toSet().toList();
}
