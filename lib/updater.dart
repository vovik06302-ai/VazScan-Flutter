import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Репозиторий с релизами приложения
const String kRepo = 'vovik06302-ai/VazScan-Flutter';

class UpdateInfo {
  final String tag;
  final int code;
  final String apiUrl;
  const UpdateInfo(this.tag, this.code, this.apiUrl);
}

class Updater {
  static Map<String, String> _headers(String? token, String accept) => {
        'Accept': accept,
        'User-Agent': 'VazScan',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  /// Последний релиз или null, если версия не распознана
  static Future<UpdateInfo?> latest(String? token) async {
    final r = await http
        .get(Uri.parse('https://api.github.com/repos/$kRepo/releases/latest'),
            headers: _headers(token, 'application/vnd.github+json'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('GitHub ответил кодом ${r.statusCode}');
    final o = jsonDecode(r.body) as Map<String, dynamic>;
    final tag = o['tag_name'] as String;
    final code = int.tryParse(tag.split('.').last);
    if (code == null) return null;
    for (final a in (o['assets'] as List)) {
      final m = a as Map<String, dynamic>;
      if ((m['name'] as String).endsWith('.apk')) {
        return UpdateInfo(tag, code, m['url'] as String);
      }
    }
    return null;
  }

  static Future<File> download(UpdateInfo u, String? token, void Function(double) onProgress) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(u.apiUrl))
        ..headers.addAll(_headers(token, 'application/octet-stream'))
        ..followRedirects = false;
      var res = await client.send(req);
      if (res.statusCode >= 300 && res.statusCode < 400) {
        // Временная ссылка на файл на другом домене: без токена
        final loc = res.headers['location'];
        if (loc == null) throw Exception('Нет ссылки на файл');
        res = await client.send(http.Request('GET', Uri.parse(loc)));
      }
      if (res.statusCode != 200) throw Exception('Не удалось скачать APK: код ${res.statusCode}');
      final total = res.contentLength ?? 0;
      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}/updates')..createSync(recursive: true);
      final file = File('${dir.path}/VazScan-${u.tag}.apk');
      final sink = file.openWrite();
      var done = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        done += chunk.length;
        if (total > 0) onProgress(done / total);
      }
      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  static Future<void> install(File f) async {
    await OpenFilex.open(f.path, type: 'application/vnd.android.package-archive');
  }
}
