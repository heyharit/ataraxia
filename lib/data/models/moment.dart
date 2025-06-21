enum TimeOfDayMoment { morning, evening, night }

String slugFromImageKey(String imageKey) {
  final file = imageKey.split('/').last.split('.').first;

  return file
      .toLowerCase()
      .replaceAll('_', '-')
      .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
}

class Moment {
  final String wallpaperId;
  final String id;
  final String slug;
  final String title;
  final String quote;
  final String? author;
  final String imageKey;
  final String? depthMapKey;
  final String? midLayerKey;
  final String? foreLayerKey;
  final String type;
  final List<String> tags;
  final String? season;
  final TimeOfDayMoment time;

  Moment({
    required this.wallpaperId,
    required this.id,
    String? slug,
    required this.title,
    required this.quote,
    required this.imageKey,
    required this.time,
    this.depthMapKey,
    this.midLayerKey,
    this.foreLayerKey,
    this.type = 'static',
    this.author,
    required this.tags,
    this.season,
  }) : slug = slug ?? slugFromImageKey(imageKey);

  bool get is3D => type == 'parallax' && depthMapKey != null;
  bool get isParallax => type == 'parallax';
  bool get is360 => type == 'panorama';

  Map<String, dynamic> toJson() => {
    'wallpaper_id': wallpaperId,
    'id': id,
    'slug': slug,
    'title': title,
    'quote': quote,
    'author': author,
    'image_path': imageKey,
    'depth_map_path': depthMapKey,
    'layer_mid_path': midLayerKey,
    'layer_fore_path': foreLayerKey,
    'type': type,
    'time': time.name,
    'tags': tags,
    'season': season,
  };

  factory Moment.fromJson(Map<String, dynamic> json) {
    final imageKey = json['image_path'] ?? json['image_key'] ?? '';

    return Moment(
      wallpaperId: json['wallpaper_id'] ?? json['id'] ?? '',
      id: json['id'] ?? json['wallpaper_id'] ?? '',
      slug: json['slug'] as String?, 
      title: json['title'] ?? '',
      quote: json['quote'] ?? '',
      author: json['author'] as String?,
      imageKey: imageKey,
      depthMapKey: json['depth_map_path'],
      midLayerKey: json['layer_mid_path'],
      foreLayerKey: json['layer_fore_path'],
      type: json['type'] ?? 'static',
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      season: json['season'] as String?,
      time: TimeOfDayMoment.values.firstWhere(
        (t) => t.name == (json['time'] ?? 'morning'),
        orElse: () => TimeOfDayMoment.morning,
      ),
    );
  }
}
