import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'models/identity.dart';
import 'package:uuid/uuid.dart';
import '../supabase/supabase_service.dart';

class CreatedIdentity {
  final Identity identity;
  final String key;
  final String recoveryPhrase;

  CreatedIdentity({
    required this.identity,
    required this.key,
    required this.recoveryPhrase,
  });
}

class IdentityStore {
  static const _identitiesKey = 'ataraxia_identities';
  static const _activeIdentityKey = 'ataraxia_active_identity';

  static final _uuid = const Uuid();

  // ───────────────────────────────
  static String _hashKey(String key) {
    return sha256.convert(utf8.encode(key)).toString();
  }

  // ───────────────────────────────
  static Future<List<Identity>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_identitiesKey) ?? [];
    return raw.map((e) => Identity.fromJson(jsonDecode(e))).toList();
  }

  // ───────────────────────────────
  static Future<bool> nameExists(String name) async {
    final normalized = name.trim().toLowerCase();

    final remoteExists = await SupabaseService.nameExists(normalized);
    if (remoteExists) return true;

    final identities = await all();
    return identities.any((i) => i.name.toLowerCase() == normalized);
  }

  // ───────────────────────────────
  /// 🔥 CREATION — returns identity + key ONCE

  /// 🔥 CREATION — returns identity + key + cipher ONCE
  static Future<CreatedIdentity> create({
    required String name,
    required String key,
  }) async {
    final displayName = name.trim();
    final normalized = displayName.toLowerCase();

    final exists = await SupabaseService.nameExists(normalized);
    if (exists) throw Exception('NAME_TAKEN');

    // 1. 🌌 Generate the 12-word Master Cipher
    final mnemonic = bip39.generateMnemonic();

    // 2. Hash the cipher so the database never sees the raw words
    final cleanMnemonic = mnemonic.trim().toLowerCase();
    final recoveryHash = _hashKey(cleanMnemonic);

    final identity = Identity(
      id: _uuid.v4(),
      name: displayName,
      keyHash: _hashKey(key),
      createdAt: DateTime.now(),
      recoveryPhrase: mnemonic,
    );

    final prefs = await SharedPreferences.getInstance();
    final identities = await all();
    identities.add(identity);

    await prefs.setStringList(
      _identitiesKey,
      identities.map((i) => jsonEncode(i.toJson())).toList(),
    );

    await setActive(identity.id);

    // 3. 🚀 Pass the recoveryHash to the database
    await SupabaseService.createUser(
      identity,
      nameNormalized: normalized,
      rawKey: key,
      recoveryHash: recoveryHash, // 👈 YOU WILL NEED TO ADD THIS PARAMETER
    );

    // 4. Return the raw phrase to the UI so they can copy it
    return CreatedIdentity(
      identity: identity,
      key: key,
      recoveryPhrase: mnemonic, // 👈 RETURN IT HERE
    );
  }

  // Add this inside the IdentityStore class:

  /// 🪶 RECOVER LOST IDENTITY
  static Future<bool> recoverWithCipher({
    required String phrase,
    required String newKey,
  }) async {
    // 1. Normalize the phrase (lowercase, single spaces only)
    final cleanPhrase = phrase.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final phraseHash = _hashKey(cleanPhrase);

    // 2. Hash their new desired password
    final newKeyHash = _hashKey(newKey);

    // 3. Attempt database recovery
    final recoveredUserId = await SupabaseService.recoverIdentity(
      recoveryHash: phraseHash,
      newKeyHash: newKeyHash,
      newRawKey: newKey,
    );

    if (recoveredUserId == null) return false; // Invalid phrase

    // 4. Recovery successful! Fetch their identity data
    final identity = await SupabaseService.fetchIdentity(recoveredUserId);
    if (identity == null) return false;

    // 5. Update local storage and log them in
    final prefs = await SharedPreferences.getInstance();
    final identities = await all();

    // Remove the old local instance if it somehow exists, and add the fresh one
    identities.removeWhere((i) => i.id == identity.id);
    identities.add(identity);

    await prefs.setStringList(
      _identitiesKey,
      identities.map((i) => jsonEncode(i.toJson())).toList(),
    );

    await setActive(identity.id);
    return true;
  }

  // static Future<CreatedIdentity> create({
  //   required String name,
  //   required String key,
  // }) async {
  //   final normalized = name.trim().toLowerCase();
  //   final exists = await nameExists(normalized);
  //   if (exists) throw Exception('NAME_TAKEN');

  //   final identity = Identity(
  //     id: _uuid.v4(),
  //     name: name.trim(),
  //     keyHash: _hashKey(key),
  //     createdAt: DateTime.now(),
  //   );

  //   final prefs = await SharedPreferences.getInstance();
  //   final identities = await all();
  //   identities.add(identity);

  //   await prefs.setStringList(
  //     _identitiesKey,
  //     identities.map((i) => jsonEncode(i.toJson())).toList(),
  //   );

  //   await setActive(identity.id);

  //   // await SupabaseService.createUser(identity, rawKey: key);
  //   await SupabaseService.createUser(identity);

  //   return CreatedIdentity(identity: identity, key: key);
  // }

  // ───────────────────────────────

  // ───────────────────────────────
  /// 🪶 REDEFINE IDENTITY (Change Name)
  static Future<Identity> updateName(String newName) async {
    final current = await active();
    if (current == null) throw Exception('NO_ACTIVE_IDENTITY');

    final normalized = newName.trim().toLowerCase();

    // If it's the exact same name, do nothing
    if (normalized == current.name.toLowerCase()) return current;

    // Check availability
    final exists = await nameExists(normalized);
    if (exists) throw Exception('NAME_TAKEN');

    // 1. Update Database
    await SupabaseService.updateName(current.id, newName.trim(), normalized);

    // 2. Update Local Storage
    final updatedIdentity = Identity(
      id: current.id,
      name: newName.trim(),
      keyHash: current.keyHash,
      createdAt: current.createdAt,
    );

    final prefs = await SharedPreferences.getInstance();
    final identities = await all();
    final index = identities.indexWhere((i) => i.id == current.id);

    if (index != -1) {
      identities[index] = updatedIdentity;
    } else {
      identities.add(updatedIdentity);
    }

    await prefs.setStringList(
      _identitiesKey,
      identities.map((i) => jsonEncode(i.toJson())).toList(),
    );

    return updatedIdentity;
  }

  // ───────────────────────────────

  static Future<Identity?> authenticate({
    required String name,
    required String key,
  }) async {
    final normalized = name.trim().toLowerCase();
    final hash = _hashKey(key);

    final remote = await SupabaseService.authenticate(normalized, hash);

    if (remote == null) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_identitiesKey, [jsonEncode(remote.toJson())]);

    await setActive(remote.id);
    return remote;
  }

  // static Future<Identity?> authenticate({
  //   required String name,
  //   required String key,
  // }) async {
  //   final hash = _hashKey(key);

  //   final remote = await SupabaseService.authenticate(name, hash);
  //   if (remote == null) return null;

  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setStringList(_identitiesKey, [jsonEncode(remote.toJson())]);

  //   await setActive(remote.id);
  //   return remote;
  // }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeIdentityKey);
  }

  // ─── ECONOMY & GHOST PROTOCOL ───

  // 🚀 Silently updates the local cache with the absolute latest database data
  static Future<void> syncFromNetwork() async {
    final current = await active();
    if (current == null) return;

    final remote = await SupabaseService.fetchIdentity(current.id);
    if (remote != null) {
      final prefs = await SharedPreferences.getInstance();
      final identities = await all();
      final index = identities.indexWhere((i) => i.id == current.id);

      if (index != -1) {
        // CRITICAL: Preserve the local cipher because the server doesn't have it!
        final preservedCipher = identities[index].recoveryPhrase;

        final mergedIdentity = Identity(
          id: remote.id,
          name: remote.name,
          keyHash: remote.keyHash,
          createdAt: remote.createdAt,
          axioms: remote.axioms,
          isPremium: remote.isPremium,
          hasInfiniteArchives: remote.hasInfiniteArchives,
          recoveryPhrase: preservedCipher,
        );

        identities[index] = mergedIdentity;
        await prefs.setStringList(
          _identitiesKey,
          identities.map((i) => jsonEncode(i.toJson())).toList(),
        );
      }
    }
  }

  // static Future<void> updateLocalBalance(int newBalance) async {
  //   final current = await active();
  //   if (current == null) return;

  //   final updatedIdentity = Identity(
  //     id: current.id,
  //     name: current.name,
  //     keyHash: current.keyHash,
  //     createdAt: current.createdAt,
  //     axioms: newBalance,
  //     isPremium: current.isPremium,
  //   );

  //   final prefs = await SharedPreferences.getInstance();
  //   final identities = await all();
  //   final index = identities.indexWhere((i) => i.id == current.id);

  //   if (index != -1) {
  //     identities[index] = updatedIdentity;
  //     await prefs.setStringList(
  //       _identitiesKey,
  //       identities.map((i) => jsonEncode(i.toJson())).toList(),
  //     );
  //   }
  // }

  static const _ghostAppliesKey = 'ataraxia_ghost_applies';

  static Future<int> getGhostApplies() async {
    final prefs = await SharedPreferences.getInstance();
    // Give them 3 free applies by default if the key doesn't exist
    if (!prefs.containsKey(_ghostAppliesKey)) {
      await prefs.setInt(_ghostAppliesKey, 3);
      return 3;
    }
    return prefs.getInt(_ghostAppliesKey) ?? 0;
  }

  static Future<void> decrementGhostApplies() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getGhostApplies();
    if (current > 0) {
      await prefs.setInt(_ghostAppliesKey, current - 1);
    }
  }

  static Future<void> addGhostApplies(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getGhostApplies();
    await prefs.setInt(_ghostAppliesKey, current + amount);
  }

  // ───────────────────────────────
  static Future<void> setActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeIdentityKey, id);
  }

  static Future<Identity?> active() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_activeIdentityKey);
    if (id == null) return null;

    final identities = await all();
    return identities.firstWhere((i) => i.id == id);
  }

  // ───────────────────────────────
  /// 🔐 EXPORT PAYLOAD (creation-only)
  static String buildExport({required Identity identity, required String key}) {
    final payload = {
      'type': 'ataraxia.identity',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'identity': identity.toJson(),
      'key': key,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  // ───────────────────────────────
  static Future<void> importFromFile(String contents) async {
    final json = jsonDecode(contents);

    if (json['type'] != 'ataraxia.identity') {
      throw Exception('INVALID_ATARAXIAN');
    }

    final identity = Identity.fromJson(json['identity']);
    final key = json['key'];

    // 🔐 validate key
    final hash = _hashKey(key);
    if (hash != identity.keyHash) {
      throw Exception('KEY_MISMATCH');
    }

    // save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_identitiesKey, [jsonEncode(identity.toJson())]);

    await setActive(identity.id);
  }

  static bool verifyKey(Identity identity, String key) {
    return _hashKey(key) == identity.keyHash;
  }

  // ───────────────────────────────
  // static Future<void> burnIdentity({required String confirmName}) async {
  //   final identity = await active();
  //   if (identity == null) throw Exception('NO_ACTIVE_IDENTITY');

  //   if (confirmName != identity.name) {
  //     throw Exception('NAME_MISMATCH');
  //   }

  //   // 🔥 SERVER OBLITERATION
  //   await SupabaseService.deleteIdentityCompletely(identity.id);

  //   // 🔥 LOCAL OBLITERATION
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.remove(_activeIdentityKey);
  //   await prefs.remove(_identitiesKey);
  // }

  static Future<void> burnIdentity({required String confirmName}) async {
    final identity = await active();
    if (identity == null) throw Exception('NO_ACTIVE_IDENTITY');

    if (confirmName != identity.name) {
      throw Exception('NAME_MISMATCH');
    }

    // 🔥 SERVER OBLITERATION
    await SupabaseService.deleteIdentityCompletely(identity.id);

    // 🔥 LOCAL OBLITERATION
    final prefs = await SharedPreferences.getInstance();

    // 1. Fetch all local identities
    final identities = await all();

    // 2. Remove ONLY the active one from the list
    identities.removeWhere((i) => i.id == identity.id);

    if (identities.isEmpty) {
      // If that was the last identity, clean up the key entirely
      await prefs.remove(_identitiesKey);
    } else {
      // Otherwise, save the remaining identities back to storage
      await prefs.setStringList(
        _identitiesKey,
        identities.map((i) => jsonEncode(i.toJson())).toList(),
      );
    }

    // 3. Clear the active session
    await prefs.remove(_activeIdentityKey);
  }
}
