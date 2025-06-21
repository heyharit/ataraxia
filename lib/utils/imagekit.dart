class ImageKit {
  static const String endpoint = 'https://ik.imagekit.io/themadbrogrammers';

  static String original(String path) {
    return '$endpoint/$path';
  }

  static String cropped({
    required String path,
    required double width,
    required double height,
  }) {
    final w = width.round();
    final h = height.round();

    return '$endpoint/$path?tr=w-$w,h-$h,c-maintain_ratio';
  }

  static String blurred(String path) {
    return '$endpoint/$path?tr=bl-30';
  }

  static String thumb(String path) {
    return '$endpoint/$path?tr=w-400,q-60';
  }

  static String constrainedWidth({
    required String path,
    required double width,
  }) {
    final w = width.round();
    return '$endpoint/$path?tr=w-$w';
  }
}
