/// Favorite presets — persisted via SharedPreferences.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A named preset the user can save and recall.
class FavoritePreset {
  /// Creates a preset.
  const FavoritePreset({
    required this.id,
    required this.name,
    required this.settingsJson,
  });

  /// Stable identifier.
  final String id;

  /// User-given name.
  final String name;

  /// JSON-serialised settings (ASCII or sketch).
  final Map<String, dynamic> settingsJson;

  /// Serialises to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'settings': settingsJson,
  };

  /// Deserialises from a JSON map.
  factory FavoritePreset.fromJson(Map<String, dynamic> json) => FavoritePreset(
    id: json['id'] as String,
    name: json['name'] as String,
    settingsJson:
        (json['settings'] as Map<String, dynamic>?) ?? <String, dynamic>{},
  );
}

/// Repository abstraction for favorite presets.
abstract class FavoritesRepository {
  /// Loads the list.
  Future<List<FavoritePreset>> load();

  /// Saves the list.
  Future<void> save(List<FavoritePreset> presets);
}

/// SharedPreferences-backed repository.
class PrefsFavoritesRepository implements FavoritesRepository {
  /// Creates with an already-resolved instance.
  PrefsFavoritesRepository(this._prefs);

  final SharedPreferences _prefs;
  static const String _kKey = 'favorite_presets';

  @override
  Future<List<FavoritePreset>> load() async {
    final String? raw = _prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return <FavoritePreset>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (dynamic e) => FavoritePreset.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on Object {
      return <FavoritePreset>[];
    }
  }

  @override
  Future<void> save(List<FavoritePreset> presets) async {
    final String raw = jsonEncode(
      presets.map((FavoritePreset p) => p.toJson()).toList(),
    );
    await _prefs.setString(_kKey, raw);
  }
}

/// In-memory repository for tests.
class InMemoryFavoritesRepository implements FavoritesRepository {
  /// Creates with optional initial list.
  InMemoryFavoritesRepository([List<FavoritePreset>? initial])
    : _presets = initial ?? <FavoritePreset>[];

  List<FavoritePreset> _presets;

  @override
  Future<List<FavoritePreset>> load() async =>
      List<FavoritePreset>.from(_presets);

  @override
  Future<void> save(List<FavoritePreset> presets) async {
    _presets = List<FavoritePreset>.from(presets);
  }
}

/// Controller for favorite presets.
class FavoritesController extends Notifier<List<FavoritePreset>> {
  @override
  List<FavoritePreset> build() {
    // Load asynchronously; start empty.
    _loadAsync();
    return <FavoritePreset>[];
  }

  Future<void> _loadAsync() async {
    final FavoritesRepository repo = ref.read(favoritesRepositoryProvider);
    final List<FavoritePreset> loaded = await repo.load();
    state = loaded;
  }

  /// Adds a preset.
  Future<void> add(FavoritePreset preset) async {
    final List<FavoritePreset> next = <FavoritePreset>[...state, preset];
    state = next;
    await ref.read(favoritesRepositoryProvider).save(next);
  }

  /// Removes a preset by id.
  Future<void> remove(String id) async {
    final List<FavoritePreset> next = state
        .where((FavoritePreset p) => p.id != id)
        .toList();
    state = next;
    await ref.read(favoritesRepositoryProvider).save(next);
  }

  /// Clears all presets.
  Future<void> clear() async {
    state = <FavoritePreset>[];
    await ref.read(favoritesRepositoryProvider).save(<FavoritePreset>[]);
  }
}

/// Repository provider — override in main.dart or tests.
final Provider<FavoritesRepository> favoritesRepositoryProvider =
    Provider<FavoritesRepository>((Ref ref) {
      throw UnimplementedError(
        'favoritesRepositoryProvider must be overridden',
      );
    });

/// Public provider for the favorites list.
final NotifierProvider<FavoritesController, List<FavoritePreset>>
favoritesProvider = NotifierProvider<FavoritesController, List<FavoritePreset>>(
  FavoritesController.new,
);
