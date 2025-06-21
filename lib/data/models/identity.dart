class Identity {
  final String id;
  final String name;
  final String keyHash;
  final DateTime createdAt;
  final int axioms;
  final bool isPremium;
  final bool hasInfiniteArchives;
  final String? recoveryPhrase;

  Identity({
    required this.id,
    required this.name,
    required this.keyHash,
    required this.createdAt,
    this.axioms = 0,
    this.isPremium = false,
    this.hasInfiniteArchives = false,
    this.recoveryPhrase,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'keyHash': keyHash,
    'createdAt': createdAt.toIso8601String(),
    'axioms': axioms,
    'is_premium': isPremium,
    'has_infinite_archives': hasInfiniteArchives,
    if (recoveryPhrase != null) 'recoveryPhrase': recoveryPhrase,
  };

  factory Identity.fromJson(Map<String, dynamic> json) {
    return Identity(
      id: json['id'],
      name: json['name'],
      keyHash: json['key_hash'] ?? json['keyHash'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      axioms: json['axioms'] ?? 0,
      isPremium: json['is_premium'] ?? false,
      hasInfiniteArchives: json['has_infinite_archives'] ?? false,
      recoveryPhrase: json['recoveryPhrase'],
    );
  }

  // Helper to easily update balance locally without full DB refresh
  Identity copyWith({
    int? axioms,
    bool? isPremium,
    bool? hasInfiniteArchives,
    String? recoveryPhrase,
  }) {
    return Identity(
      id: id,
      name: name,
      keyHash: keyHash,
      createdAt: createdAt,
      axioms: axioms ?? this.axioms,
      isPremium: isPremium ?? this.isPremium,
      hasInfiniteArchives: hasInfiniteArchives ?? this.hasInfiniteArchives,
      recoveryPhrase: recoveryPhrase ?? this.recoveryPhrase,
    );
  }
}
