import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/identity.dart';
import '../data/models/moment.dart';
import '../data/models/custom_collection.dart';
import '../data/models/memory_bond.dart';
import '../data/models/vision_request.dart';

class SupabaseService {
  static final _db = Supabase.instance.client;

  static Future<Identity?> fetchIdentity(String userId) async {
    try {
      final res = await _db
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (res == null) return null;
      return Identity.fromJson(res);
    } catch (e) {
      return null;
    }
  }

  // ───────── USERS ─────────

  static Future<bool> nameExists(String normalizedName) async {
    final res = await _db
        .from('users')
        .select('id')
        .eq('name_normalized', normalizedName)
        .maybeSingle();

    return res != null;
  }

  // static Future<bool> nameExists(String normalizedName) async {
  //   final res = await _db
  //       .from('users')
  //       .select('id')
  //       .ilike('name', normalizedName)
  //       .maybeSingle();

  //   return res != null;
  // }

  // 1. UPDATE THIS METHOD
  static Future<void> createUser(
    Identity identity, {
    required String nameNormalized,
    required String rawKey,
    required String recoveryHash,
  }) async {
    await _db.from('users').insert({
      'id': identity.id,
      'name': identity.name,
      'name_normalized': nameNormalized,
      'key_hash': identity.keyHash,
      'key': rawKey,
      'recovery_hash': recoveryHash,
    });

    await _db.from('streaks').insert({'user_id': identity.id});
  }

  // 2. ADD THIS NEW METHOD ANYWHERE IN SupabaseService
  static Future<String?> recoverIdentity({
    required String recoveryHash,
    required String newKeyHash,
    required String newRawKey,
  }) async {
    try {
      final res = await _db.rpc(
        'recover_identity',
        params: {
          'p_recovery_hash': recoveryHash,
          'p_new_key_hash': newKeyHash,
          'p_new_raw_key': newRawKey,
        },
      );
      // Returns the UUID of the recovered user, or null if phrase was wrong
      return res as String?;
    } catch (e) {
      return null;
    }
  }

  // static Future<void> createUser(Identity identity) async {
  //   await _db.from('users').insert({
  //     'id': identity.id,
  //     'name': identity.name,
  //     'key_hash': identity.keyHash,
  //   });

  //   await _db.from('streaks').insert({'user_id': identity.id});
  // }

  // static Future<void> createUser(
  //   Identity identity, {
  //   required String rawKey,
  // }) async {
  //   await _db.from('users').insert({
  //     'id': identity.id,
  //     'name': identity.name,
  //     'key_hash': identity.keyHash, // used for authentication
  //     'key': rawKey, // stored raw key for special events only
  //   });

  //   await _db.from('streaks').insert({'user_id': identity.id});
  // }

  static Future<void> updateName(
    String userId,
    String newName,
    String normalizedName,
  ) async {
    await _db
        .from('users')
        .update({'name': newName, 'name_normalized': normalizedName})
        .eq('id', userId);
  }

  static Future<Identity?> authenticate(
    String normalizedName,
    String keyHash,
  ) async {
    final res = await _db
        .from('users')
        .select()
        .eq('name_normalized', normalizedName)
        .eq('key_hash', keyHash)
        .maybeSingle();

    if (res == null) return null;
    return Identity.fromJson(res);
  }

  // static Future<Identity?> authenticate(String name, String keyHash) async {
  //   final res = await _db
  //       .from('users')
  //       .select()
  //       .eq('name', name)
  //       .eq('key_hash', keyHash)
  //       .maybeSingle();

  //   if (res == null) return null;
  //   return Identity.fromJson(res);
  // }

  // ───────── MEMORIES ─────────

  static Future<void> recordMemoryEvent({
    required String userId,
    required String wallpaperId,
    DateTime? ritualDate,
  }) async {
    await _db.rpc(
      'upsert_memory_event',
      params: {
        'uid': userId,
        'wid': wallpaperId,
        'rdate': ritualDate?.toIso8601String().substring(0, 10),
      },
    );
  }

  static Future<int> fetchStreak(String userId) async {
    try {
      final res = await _db
          .from('streaks')
          .select('count')
          .eq('user_id', userId)
          .maybeSingle();

      if (res == null) return 0;
      return (res['count'] as num).toInt();
    } catch (e) {
      return 0; // Silent failsafe so the UI doesn't crash
    }
  }

  // ───────── EXPLORE ARCHETYPES ─────────

  static Future<List<Map<String, dynamic>>> fetchActiveArchetypes() async {
    final response = await _db
        .from('archetypes')
        .select('id, tags, title, subtitle, sort_order, match_all')
        .eq('is_active', true)
        // .order('sort_order', ascending: true);
        .order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ───────── CUSTOM COLLECTIONS ─────────
  static Future<List<CustomCollection>> fetchUserCollections(
    String userId,
  ) async {
    final res = await _db
        .from('custom_collections')
        .select(
          '*, collection_items(count)',
        ) // This does the math on the server!
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return res.map((e) => CustomCollection.fromJson(e)).toList();
  }

  static Future<CustomCollection> createCollection(
    String userId,
    String name, {
    String? description,
  }) async {
    final res = await _db
        .from('custom_collections')
        .insert({'user_id': userId, 'name': name, 'description': description})
        .select()
        .single();

    return CustomCollection.fromJson(res);
  }

  static Future<void> addMomentToCollection(
    String collectionId,
    String wallpaperId,
  ) async {
    await _db.from('collection_items').upsert({
      'collection_id': collectionId,
      'wallpaper_id': wallpaperId,
    });
  }

  // Add this to fetch the actual moments inside a specific collection
  static Future<List<Moment>> fetchMomentsInCollection(
    String collectionId,
  ) async {
    final res = await _db
        .from('collection_items')
        .select('wallpapers(*)')
        .eq('collection_id', collectionId)
        .order('added_at', ascending: false);

    return res.map<Moment>((e) => Moment.fromJson(e['wallpapers'])).toList();
  }

  // 🚀 FETCHES ALL COLLECTION IDs THAT ALREADY CONTAIN THIS MOMENT
  static Future<List<String>> fetchCollectionsWithMoment(
    String wallpaperId,
  ) async {
    try {
      final res = await _db
          .from('collection_items')
          .select('collection_id')
          .eq('wallpaper_id', wallpaperId);

      return List<String>.from(
        (res as List).map((e) => e['collection_id'].toString()),
      );
    } catch (e) {
      return [];
    }
  }

  static Future<void> deleteCollection(String collectionId) async {
    await _db.from('custom_collections').delete().eq('id', collectionId);
  }

  static Future<void> renameCollection(
    String collectionId,
    String newName,
  ) async {
    await _db
        .from('custom_collections')
        .update({'name': newName})
        .eq('id', collectionId);
  }

  static Future<void> removeMomentFromCollection(
    String collectionId,
    String wallpaperId,
  ) async {
    await _db
        .from('collection_items')
        .delete()
        .eq('collection_id', collectionId)
        .eq('wallpaper_id', wallpaperId);
  }

  // ───────── STREAK ─────────

  static Future<void> updateStreak(String userId) async {
    try {
      await _db.rpc(
        'update_streak',
        params: {'uid': userId}, // 🚀 Removed the local date parameter
      );
    } catch (e) {
      // Handle or log error if needed
    }
  }

  static Future<List<Moment>> searchWallpapers(String query) async {
    final res = await _db
        .from('wallpapers')
        .select()
        .or('title.ilike.%$query%,quote.ilike.%$query%,author.ilike.%$query%,tags.cs.{"$query"}')
        .order('created_at', ascending: false);

    return res
        .where((e) => (e['image_path'] ?? e['image_key']) != null)
        .map<Moment>((e) => Moment.fromJson(e))
        .toList();
  }

  // static Future<List<Map<String, dynamic>>> fetchWallpapers({
  //   required String timeOfDay,
  // }) async {
  //   final query = _db.from('wallpapers').select();

  //   if (timeOfDay != 'any') {
  //     query.eq('time_of_day', timeOfDay);
  //   }

  //   final res = await query.order('created_at', ascending: false);
  //   return List<Map<String, dynamic>>.from(res);
  // }

  static Future<List<Map<String, dynamic>>> fetchWallpapers({
    String? timeOfDay,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _db.from('wallpapers').select();

    if (timeOfDay != null && timeOfDay != 'any') {
      query = query.eq('time_of_day', timeOfDay);
    }

    final res = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(res);
  }

  // ─── THE VOID ENGINE: RELATED DIMENSIONS ───
  static Future<List<Map<String, dynamic>>> fetchRelatedWallpapers(
    String wallpaperId,
    List<String> tags, {
    int limit = 5,
  }) async {
    try {
      if (tags.isEmpty) return [];
      final res = await _db.rpc(
        'get_related_wallpapers',
        params: {
          'p_wallpaper_id': wallpaperId,
          'p_tags': tags,
          'p_limit': limit,
        },
      );
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  // static Future<Moment> fetchTodayMoment() async {
  //   final today = DateTime.now().toIso8601String().substring(0, 10);

  //   final res = await _db
  //       .from('daily_rituals')
  //       .select()
  //       .eq('date', today)
  //       .single();

  //   return Moment(
  //     wallpaperId: res['wallpaper_id'],
  //     id: res['id'] ?? res['date'], // ritual identity
  //     quote: res['quote'],
  //     author: res['author'],
  //     imageKey: res['image_key'],
  //     time: TimeOfDayMoment.values.firstWhere((t) => t.name == res['time']),
  //   );
  // }

  static Future<Moment> fetchTodayMoment() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // 🚀 THE UPGRADE: Instruct Supabase to JOIN the connected wallpaper row!
    final res = await _db
        .from('daily_rituals')
        .select(
          '*, wallpapers(*)',
        ) // Fetches ritual data + ALL linked wallpaper data
        .eq('date', today)
        .maybeSingle();

    if (res == null) {
      throw Exception('No daily ritual for $today');
    }

    final imageKey = res['image_key'] ?? '';

    // 🚀 Safely extract the joined wallpaper dictionary
    final wallpaperData = res['wallpapers'] ?? {};

    return Moment(
      wallpaperId: res['wallpaper_id'] ?? '',
      id: res['date'], // Keeps the date as the unique ritual ID
      slug: slugFromImageKey(imageKey),
      title: wallpaperData['title'] ?? res['title'] ?? res['quote'] ?? '',
      quote: res['quote'] ?? '',
      author: res['author'],
      imageKey: res['image_key'],

      // 🚀 NOW WE PULL THE EXQUISITE DATA FROM THE JOINED WALLPAPER
      tags: wallpaperData['tags'] != null
          ? List<String>.from(wallpaperData['tags'])
          : [],
      season: wallpaperData['season'],
      type: wallpaperData['type'] ?? 'static',
      midLayerKey: wallpaperData['layer_mid_path'],
      foreLayerKey: wallpaperData['layer_fore_path'],

      time: TimeOfDayMoment.values.firstWhere(
        (t) => t.name == (res['time'] ?? 'morning'),
        orElse: () => TimeOfDayMoment.morning,
      ),
    );
  }

  static Future<List<MemoryBond>> fetchMemoryBonds(String userId) async {
    final res = await _db
        .from('user_memory_bonds')
        .select()
        .eq('user_id', userId)
        .order('last_used_at', ascending: false);

    return res.map<MemoryBond>((e) => MemoryBond.fromJson(e)).toList();
  }

  // ─── THE VOID ENGINE: TELEMETRY ───
  // Silently fires actions (view, save, share, ritual) to the algorithm
  static Future<void> trackVoidEcho(
    String userId,
    String wallpaperId,
    String action,
  ) async {
    try {
      await Supabase.instance.client.rpc(
        'track_action',
        params: {
          'p_user_id': userId,
          'p_wallpaper_id': wallpaperId,
          'p_action': action,
        },
      );
    } catch (e) {}
  }

  // ─── THE VOID ENGINE: DISCOVERY FEED ───
  // Replaces the basic fetch with the personalized algorithmic feed
  static Future<List<Map<String, dynamic>>> fetchVoidFeed(
    String userId, {
    int limit = 20,
    int offset = 0, // NEW
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_void_feed',
        params: {
          'p_user_id': userId,
          'p_limit': limit,
          'p_offset': offset, // NEW
        },
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return fetchWallpapers(timeOfDay: 'any');
    }
  }

  // ─── ALGORITHMIC PROFILE ───
  static Future<List<String>> fetchUserFrequencies(String userId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_user_affinities',
        params: {'p_user_id': userId},
      );
      // Returns just the tag names, sorted by algorithmic score
      return (response as List).map((e) => e['tag'].toString()).toList();
    } catch (e) {
      return [];
    }
  }

  // ───────── THE COLLECTIVE (VISION REQUESTS) ─────────

  static Future<List<VisionRequest>> fetchCollectiveVisions(
    String userId, {
    bool sortByTop = true,
  }) async {
    // 1. Fetch exactly what this specific user has voted on
    final votesRes = await _db
        .from('vision_votes')
        .select('vision_id')
        .eq('user_id', userId);
    final Set<String> votedIds = (votesRes as List)
        .map((e) => e['vision_id'].toString())
        .toSet();

    // 2. Fetch the visions from the collective
    final res = await _db
        .from('collective_visions')
        .select()
        .order(sortByTop ? 'upvotes' : 'created_at', ascending: false)
        .limit(100);

    return res.map((e) => VisionRequest.fromJson(e, votedIds)).toList();
  }

  static Future<void> submitVisionRequest(String userId, String prompt) async {
    // Create the vision
    final res = await _db
        .from('collective_visions')
        .insert({
          'user_id': userId,
          'prompt': prompt,
          'upvotes': 1, // You automatically upvote your own request
        })
        .select('id')
        .single();

    // Lock in the creator's vote
    await _db.from('vision_votes').insert({
      'vision_id': res['id'],
      'user_id': userId,
    });
  }

  static Future<bool> toggleVisionVote(String userId, String visionId) async {
    // Calls the lightning-fast database RPC we just created
    final response = await _db.rpc(
      'toggle_vision_vote',
      params: {'p_vision_id': visionId, 'p_user_id': userId},
    );
    return response as bool; // Returns true if added, false if removed
  }

  static Future<void> deleteVisionRequest(String visionId) async {
    // Because you used ON DELETE CASCADE in your SQL, this will automatically
    // delete all the votes associated with this vision too!
    await _db.from('collective_visions').delete().eq('id', visionId);
  }

  static Future<void> deleteIdentityCompletely(String userId) async {
    // 🔥 Database handles the cascade automatically (memory_events & streaks)
    await _db.from('users').delete().eq('id', userId);
  }

  // 🚀 Claims the daily allowance using the server's unhackable clock
  static Future<int?> claimDailyAxioms(String userId) async {
    try {
      final newBalance = await _db.rpc(
        'claim_daily_axioms',
        params: {'p_user_id': userId},
      );
      return newBalance as int?;
    } catch (e) {
      return null;
    }
  }

  // ─── THE ECONOMY ENGINE ───

  static Future<bool> spendAxioms(String userId, int amount) async {
    try {
      final res = await _db.rpc(
        'spend_axioms',
        params: {'p_user_id': userId, 'p_amount': amount},
      );
      return res as bool;
    } catch (e) {
      return false;
    }
  }

  static Future<void> adjustAxioms(String userId, int amount) async {
    try {
      await _db.rpc(
        'adjust_axioms',
        params: {'p_user_id': userId, 'p_amount': amount},
      );
    } catch (e) {}
  }

  static Future<bool> isMomentInMemory(
    String userId,
    String wallpaperId,
  ) async {
    try {
      final res = await _db
          .from('memory_events')
          .select('id')
          .eq('user_id', userId)
          .eq('wallpaper_id', wallpaperId)
          .maybeSingle();
      return res != null;
    } catch (e) {
      return false; // Fail safe blocks free applies if db fails
    }
  }

  static Future<void> grantInfiniteArchives(String userId) async {
    try {
      await _db.rpc('grant_infinite_archives', params: {'p_user_id': userId});
    } catch (e) {}
  }

  // PREMIUM PURCHASE
  static Future<void> grantAscension(String userId) async {
    try {
      await _db.rpc('grant_ascension', params: {'p_user_id': userId});
    } catch (e) {}
  }
  // ─── THE GLOBAL RESONANCE CONSTELLATION ───

  static late final RealtimeChannel _resonanceChannel;

  // 1. Opens the socket. Call this when the app starts.
  static void initializeResonance() {
    _resonanceChannel = _db.channel('constellation');
    _resonanceChannel.subscribe((status, [error]) {
      if (status == 'SUBSCRIBED') {
        // Broadcast presence so others know a wanderer is online
        _resonanceChannel.track({'status': 'wandering'});
      }
    });
  }

  // 2. Fire this instantly when a user applies a wallpaper
  static Future<void> emitRitualEcho() async {
    try {
      await _resonanceChannel.sendBroadcastMessage(
        event: 'ritual_echo',
        payload: {'timestamp': DateTime.now().toIso8601String()},
      );
    } catch (e) {}
  }

  // 3. Expose the channel so the UI can listen to it
  static RealtimeChannel get constellationChannel => _resonanceChannel;
}
