class VisionRequest {
  final String id;
  final String userId;
  final String prompt;
  int upvotes;
  bool hasVoted;
  final DateTime createdAt;
  final String status;

  VisionRequest({
    required this.id,
    required this.userId,
    required this.prompt,
    required this.upvotes,
    required this.hasVoted,
    required this.createdAt,
    required this.status,
  });

  factory VisionRequest.fromJson(
    Map<String, dynamic> json,
    Set<String> userVotedIds,
  ) {
    final String id = json['id'];
    return VisionRequest(
      id: id,
      userId: json['user_id'] ?? '',
      prompt: json['prompt'] ?? '',
      upvotes: json['upvotes'] ?? 0,
      hasVoted: userVotedIds.contains(id),
      createdAt: DateTime.parse(json['created_at']),
      status: json['status'] ?? 'pending',
    );
  }
}
