import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameSettings extends ChangeNotifier {
  String language = 'ja';
  bool muted = false;
  double volume = 0.35;
  final Set<String> discoveries = {};
  SharedPreferences? _preferences;
  bool _disposed = false;
  int _changes = 0;
  Future<void> _writes = Future.value();

  Future<void> load() async {
    final changesAtStart = _changes;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_disposed) return;
      _preferences = preferences;
      if (_changes == changesAtStart) {
        language = preferences.getString('language') == 'en' ? 'en' : 'ja';
        muted = preferences.getBool('muted') ?? false;
        volume = (preferences.getDouble('volume') ?? 0.35).clamp(0, 1);
      }
      discoveries.addAll(preferences.getStringList('discoveries') ?? []);
      notifyListeners();
      if (_changes != changesAtStart) save();
    } catch (_) {
      // A blocked/private browser store must not prevent playing.
    }
  }

  void update({String? language, bool? muted, double? volume}) {
    if (language != null) this.language = language == 'en' ? 'en' : 'ja';
    if (muted != null) this.muted = muted;
    if (volume != null) this.volume = volume.clamp(0, 1);
    _changes++;
    notifyListeners();
    save();
  }

  void discover(Iterable<String> keys) {
    final before = discoveries.length;
    discoveries.addAll(keys);
    if (before != discoveries.length) {
      notifyListeners();
      save();
    }
  }

  void save() {
    final preferences = _preferences;
    if (preferences == null) return;
    final savedLanguage = language;
    final savedMuted = muted;
    final savedVolume = volume;
    final savedDiscoveries = discoveries.toList()..sort();
    _writes = _writes
        .then((_) async {
          await preferences.setString('language', savedLanguage);
          await preferences.setBool('muted', savedMuted);
          await preferences.setDouble('volume', savedVolume);
          await preferences.setStringList('discoveries', savedDiscoveries);
        })
        .catchError((_) {});
    unawaited(_writes);
  }

  Future<void> flush() => _writes;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
