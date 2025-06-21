class MemoryBond {
  final String wallpaperId;
  final String imageKey;
  final String title;
  final String quote;
  final String? author;
  final int intensity;
  final DateTime lastRitualAt;

  MemoryBond({
    required this.wallpaperId,
    required this.imageKey,
    required this.title,
    required this.quote,
    this.author,
    required this.intensity,
    required this.lastRitualAt,
  });

  factory MemoryBond.fromJson(Map<String, dynamic> json) {
    return MemoryBond(
      wallpaperId: json['id'] as String,
      imageKey: json['image_key'] as String,
      title: (json['title'] ?? '') as String,
      quote: (json['quote'] ?? '') as String,
      author: json['author'] as String?,
      intensity: json['intensity'] as int,
      lastRitualAt: DateTime.parse(json['last_used_at']),
    );
  }
}
