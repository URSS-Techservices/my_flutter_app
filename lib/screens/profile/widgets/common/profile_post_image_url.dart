/// Resolves post image URL from AddPostPage format (images/media) or legacy (imageUrl).
String? profilePostImageUrlFromMap(Map<String, dynamic> data) {
  final imageUrl = data['imageUrl']?.toString();
  if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
  final images = data['images'];
  if (images is List && images.isNotEmpty) return images.first?.toString();
  final media = data['media'];
  if (media is List && media.isNotEmpty) {
    final first = media.first;
    if (first is Map && first['url'] != null) return first['url']?.toString();
  }
  return null;
}
