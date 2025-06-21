// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'models/memory.dart';
// import '../data/identity_store.dart';

// class MemoryStore {
//   static final List<Memory> _memories = [];

//   static String _keyFor(String identityId) => 'ritual_memories_$identityId';

//   static List<Memory> get all =>
//       List.unmodifiable(_memories.reversed); // newest first

//   // ───────────────────────────────
//   static Future<void> load() async {
//     final identity = await IdentityStore.active();
//     if (identity == null) {
//       _memories.clear();
//       return;
//     }

//     final prefs = await SharedPreferences.getInstance();
//     final raw = prefs.getString(_keyFor(identity.id));

//     _memories.clear();

//     if (raw == null) return;

//     final decoded = jsonDecode(raw) as List;
//     _memories.addAll(decoded.map((e) => Memory.fromJson(e)));
//   }

//   // ───────────────────────────────
//   static Future<void> add(Memory memory) async {
//     final identity = await IdentityStore.active();
//     if (identity == null) return;

//     _memories.add(memory);
//     await _persist(identity.id);
//   }

//   // ───────────────────────────────
//   static Future<void> _persist(String identityId) async {
//     final prefs = await SharedPreferences.getInstance();
//     final encoded = jsonEncode(_memories.map((m) => m.toJson()).toList());

//     await prefs.setString(_keyFor(identityId), encoded);
//   }

//   // ───────────────────────────────
//   static Future<void> clear() async {
//     final identity = await IdentityStore.active();
//     if (identity == null) return;

//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_keyFor(identity.id));
//     _memories.clear();
//   }

//   // ───────────────────────────────
//   static Future<void> replace(List<Memory> memories) async {
//     final identity = await IdentityStore.active();
//     if (identity == null) return;

//     _memories
//       ..clear()
//       ..addAll(memories);

//     await _persist(identity.id);
//   }
// }
