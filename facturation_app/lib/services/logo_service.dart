import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

const _filename = 'company_logo.jpg';

Future<File> _logoFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/$_filename');
}

Future<Uint8List?> loadLogo() async {
  try {
    final file = await _logoFile();
    if (await file.exists()) return file.readAsBytes();
  } catch (_) {}
  return null;
}

Future<void> saveLogo(Uint8List bytes) async {
  final file = await _logoFile();
  await file.writeAsBytes(bytes);
}

Future<void> deleteLogo() async {
  final file = await _logoFile();
  if (await file.exists()) await file.delete();
}

// Riverpod provider — notifies listeners when logo changes
class LogoNotifier extends StateNotifier<Uint8List?> {
  LogoNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    state = await loadLogo();
  }

  Future<void> update(Uint8List bytes) async {
    await saveLogo(bytes);
    state = bytes;
  }

  Future<void> remove() async {
    await deleteLogo();
    state = null;
  }
}

final logoProvider = StateNotifierProvider<LogoNotifier, Uint8List?>((ref) {
  return LogoNotifier();
});
