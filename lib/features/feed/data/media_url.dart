/// Instagram-style delivery: small preview first, feed-sized file second.
/// Cloudinary URLs are rewritten. Firebase adaptive URLs are left as stored.
class MediaUrl {
  static String feed(String url) => _transform(url, 'w_720,c_limit,q_auto:eco,f_auto');

  static String thumb(String url) =>
      _transform(url, 'w_64,c_limit,q_auto:low,f_auto,e_blur:800');

  static String poster(String videoUrl) {
    if (!_isCloudinary(videoUrl)) return '';
    return _transform(videoUrl, 'so_0,w_480,q_auto,f_jpg');
  }

  static String _transform(String url, String tx) {
    if (url.isEmpty || !_isCloudinary(url)) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final parts = uri.pathSegments;
    final uploadAt = parts.indexOf('upload');
    if (uploadAt < 0 || uploadAt + 1 >= parts.length) return url;
    final next = parts[uploadAt + 1];
    if (next.contains(',') || (next.contains('_') && !next.startsWith('v'))) {
      return url;
    }
    return uri
        .replace(pathSegments: [
          ...parts.sublist(0, uploadAt + 1),
          tx,
          ...parts.sublist(uploadAt + 1),
        ])
        .toString();
  }

  static bool _isCloudinary(String url) {
    return url.contains('res.cloudinary.com');
  }
}
