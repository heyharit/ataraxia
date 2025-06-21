class CustomCollection {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final int itemCount; // 🚀 NEW: Tracks how many moments are inside

  CustomCollection({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.createdAt,
    this.itemCount = 0,
  });

  factory CustomCollection.fromJson(Map<String, dynamic> json) {
    // 🚀 Supabase returns the relation count as a nested array
    int count = 0;
    if (json['collection_items'] != null &&
        json['collection_items'] is List &&
        json['collection_items'].isNotEmpty) {
      count = json['collection_items'][0]['count'] ?? 0;
    }

    return CustomCollection(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      itemCount: count, // 🚀 Assigned here
    );
  }
}
