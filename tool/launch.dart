// รัน `flutter run` ตาม configuration ใน .vscode/launch.json โดยไม่ต้องเปิด VS Code
//
// ใช้งาน:
//   dart tool/launch.dart                      # แสดงรายการแล้วให้เลือก
//   dart tool/launch.dart "Dev Web Windows"    # เลือกตามชื่อ (ไม่สนตัวพิมพ์เล็ก/ใหญ่)
//   dart tool/launch.dart 5                    # เลือกตามลำดับในรายการ
//   dart tool/launch.dart 1 -d emulator-5554   # args ที่เหลือส่งต่อให้ flutter run
//   dart tool/launch.dart --list               # แสดงรายการแล้วจบ
//   dart tool/launch.dart --dry-run 1          # พิมพ์คำสั่งโดยไม่รัน
import 'dart:convert';
import 'dart:io';

const _launchFile = '.vscode/launch.json';

Future<void> main(List<String> arguments) async {
  final projectRoot = File.fromUri(Platform.script).parent.parent;
  Directory.current = projectRoot.path;

  final args = [...arguments];
  final listOnly = args.remove('--list') || args.remove('-l');
  final dryRun = args.remove('--dry-run') || args.remove('-n');

  final configs = _readConfigs();
  if (configs.isEmpty) _fail('ไม่พบ configuration ใน $_launchFile');

  if (listOnly) {
    _printConfigs(configs);
    return;
  }

  final Map<String, dynamic> config;
  if (args.isNotEmpty && !args.first.startsWith('-')) {
    config = _findConfig(configs, args.removeAt(0));
  } else {
    config = _promptConfig(configs);
  }

  final flutterArgs = [
    'run',
    ..._configToArgs(config),
    // args จาก command line อยู่ท้ายสุดเพื่อ override ค่าใน launch.json ได้
    ...args,
  ];

  stdout.writeln('▶ ${config['name']}');
  stdout.writeln('  flutter ${flutterArgs.map(_quote).join(' ')}');
  if (dryRun) return;

  // ปล่อยให้ flutter จัดการ Ctrl+C เอง ส่วน script นี้รอจน process ลูกจบ
  final sigintSub = ProcessSignal.sigint.watch().listen((_) {});
  final process = await Process.start(
    'flutter',
    flutterArgs,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  final code = await process.exitCode;
  await sigintSub.cancel();
  exit(code);
}

List<Map<String, dynamic>> _readConfigs() {
  final file = File(_launchFile);
  if (!file.existsSync()) _fail('ไม่พบไฟล์ $_launchFile');

  final Object? decoded;
  try {
    decoded = jsonDecode(_stripJsonc(file.readAsStringSync()));
  } on FormatException catch (e) {
    _fail('อ่าน $_launchFile ไม่ได้: ${e.message}');
  }

  final configurations = decoded is Map ? decoded['configurations'] : null;
  if (configurations is! List) return [];
  return configurations
      .whereType<Map<String, dynamic>>()
      .where((c) => c['type'] == 'dart' && c['request'] == 'launch')
      .toList();
}

/// launch.json เป็น JSONC จึงตัด comment และ trailing comma ออกก่อน decode
/// (ข้าม `//` ที่อยู่ใน string เช่น URL)
String _stripJsonc(String source) {
  final out = StringBuffer();
  var inString = false;
  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (inString) {
      out.write(char);
      if (char == r'\') {
        out.write(next);
        i++;
      } else if (char == '"') {
        inString = false;
      }
    } else if (char == '"') {
      inString = true;
      out.write(char);
    } else if (char == '/' && next == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      out.write('\n');
    } else if (char == '/' && next == '*') {
      final end = source.indexOf('*/', i + 2);
      i = end == -1 ? source.length : end + 1;
    } else {
      out.write(char);
    }
  }
  return out.toString().replaceAll(RegExp(r',(\s*[}\]])'), r'$1');
}

List<String> _configToArgs(Map<String, dynamic> config) {
  final deviceId = config['deviceId'];
  final program = config['program'];
  final flutterMode = config['flutterMode'];
  final toolArgs = config['toolArgs'];
  final appArgs = config['args'];

  return [
    if (deviceId is String) ...['-d', deviceId],
    if (program is String) ...['-t', program],
    if (flutterMode == 'profile' || flutterMode == 'release') '--$flutterMode',
    if (toolArgs is List) ...toolArgs.map((a) => '$a'),
    if (appArgs is List)
      for (final a in appArgs) '--dart-entrypoint-args=$a',
  ];
}

Map<String, dynamic> _findConfig(
  List<Map<String, dynamic>> configs,
  String query,
) {
  final index = int.tryParse(query);
  if (index != null) {
    if (index < 1 || index > configs.length) {
      _printConfigs(configs);
      _fail('ลำดับ $index ไม่อยู่ในช่วง 1-${configs.length}');
    }
    return configs[index - 1];
  }

  final lower = query.toLowerCase();
  for (final c in configs) {
    if ('${c['name']}'.toLowerCase() == lower) return c;
  }
  _printConfigs(configs);
  _fail('ไม่พบ configuration ชื่อ "$query"');
}

Map<String, dynamic> _promptConfig(List<Map<String, dynamic>> configs) {
  _printConfigs(configs);
  stdout.write('เลือก (1-${configs.length}): ');
  final input = stdin.readLineSync()?.trim() ?? '';
  if (input.isEmpty) _fail('ยกเลิก');
  return _findConfig(configs, input);
}

void _printConfigs(List<Map<String, dynamic>> configs) {
  for (var i = 0; i < configs.length; i++) {
    stdout.writeln('  ${i + 1}. ${configs[i]['name']}');
  }
}

String _quote(String arg) => arg.contains(' ') ? '"$arg"' : arg;

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
