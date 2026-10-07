import 'package:flutter/material.dart';

/// Halo / chat theme colors – keep in sync with your other chat files
const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep Purple
const Color kBubbleIncoming = Colors.white;
const Color kBubbleOutgoing = kSecondaryColor;

/// Reusable WhatsApp-style message bubble
class MessageBubble extends StatelessWidget {
  final bool isMe;
  final String text;
  final DateTime? timestamp;
  final bool seen;
  final bool delivered;
  final String messageType; // text, image, video, audio, document, location, system
  final Map<String, dynamic>? metadata;
  final bool isDeleted;
  final bool isEdited;
  final bool isForwarded;
  final String? replyPreviewText;
  final Map<String, dynamic>? reactions; // {userId: "😀"}
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const MessageBubble({
    Key? key,
    required this.isMe,
    required this.text,
    this.timestamp,
    this.seen = false,
    this.delivered = false,
    this.messageType = 'text',
    this.metadata,
    this.isDeleted = false,
    this.isEdited = false,
    this.isForwarded = false,
    this.replyPreviewText,
    this.reactions,
    this.onLongPress,
    this.onTap,
  }) : super(key: key);

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    // System messages: center aligned pill
    if (messageType == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Center(
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ),
      );
    }

    final bubbleColor = isMe ? kBubbleOutgoing : kBubbleIncoming;
    final textColor = isMe ? Colors.white : Colors.black87;

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );

    final timeStr = _formatTime(timestamp);

    // Collect unique reactions from map values
    final allReactions =
        reactions?.values.map((e) => e.toString()).toList() ?? const [];
    final uniqueReactions = allReactions.toSet().toList();

    Widget bubbleContent = Column(
      crossAxisAlignment:
      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isForwarded)
          Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.forward,
                  size: 14,
                  color: isMe ? Colors.white70 : Colors.grey[700],
                ),
                const SizedBox(width: 4),
                Text(
                  'Forwarded',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: isMe ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

        if (replyPreviewText != null && replyPreviewText!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isMe
                    ? Colors.white.withOpacity(0.3)
                    : Colors.black.withOpacity(0.08),
                width: 0.6,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 3,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white70
                        : kSecondaryColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: Text(
                    replyPreviewText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isMe
                          ? Colors.white.withOpacity(0.9)
                          : Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Main message body (text / image / other)
        _buildMessageBody(textColor),

        const SizedBox(height: 3),

        // Time + ticks / edited
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isEdited)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Text(
                  'edited',
                  style: TextStyle(
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                    color: isMe
                        ? Colors.white70
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            if (timeStr.isNotEmpty)
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe
                      ? Colors.white70
                      : Colors.grey.shade600,
                ),
              ),
            if (isMe) const SizedBox(width: 4),
            if (isMe)
              Icon(
                seen
                    ? Icons.done_all_rounded
                    : (delivered
                    ? Icons.done_all_rounded
                    : Icons.check_rounded),
                size: 14,
                color: seen
                    ? Colors.lightBlueAccent
                    : (delivered
                    ? Colors.white70
                    : Colors.white70),
              ),
          ],
        ),
      ],
    );

    // Add reactions badge under bubble
    Widget wrappedBubble = Column(
      crossAxisAlignment:
      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: onLongPress,
            onTap: onTap,
            borderRadius: borderRadius,
            child: Container(
              constraints: BoxConstraints(
                maxWidth:
                MediaQuery.of(context).size.width * 0.72,
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 8,
                    spreadRadius: -4,
                    offset: const Offset(0, 4),
                    color: Colors.black.withOpacity(0.12),
                  ),
                ],
              ),
              child: bubbleContent,
            ),
          ),
        ),
        if (uniqueReactions.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              top: 3,
              left: isMe ? 0 : 6,
              right: isMe ? 6 : 0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 6,
                    spreadRadius: -3,
                    offset: const Offset(0, 2),
                    color: Colors.black.withOpacity(0.15),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: uniqueReactions
                    .map((emoji) => Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 13),
                  ),
                ))
                    .toList(),
              ),
            ),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 4),
          if (!isMe)
            const CircleAvatar(
              radius: 14,
              backgroundImage:
              AssetImage('assets/images/Profile.png'),
            ),
          if (!isMe) const SizedBox(width: 6),
          Flexible(child: wrappedBubble),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// Builds different layouts for different message types.
  Widget _buildMessageBody(Color textColor) {
    if (isDeleted) {
      return Text(
        'This message was deleted',
        style: TextStyle(
          color: isMe ? Colors.white70 : Colors.grey[700],
          fontStyle: FontStyle.italic,
          fontSize: 13,
        ),
      );
    }

    switch (messageType) {
      case 'image':
        final imageUrl = metadata?['imageUrl']?.toString() ?? '';
        final caption = metadata?['caption']?.toString() ?? text;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => Container(
                      color: Colors.black12,
                      child: const Center(
                        child: Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
              ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                caption,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        );

      case 'video':
        final thumbUrl =
            metadata?['thumbnailUrl']?.toString() ?? '';
        final caption = metadata?['caption']?.toString() ?? text;
        final durationSeconds = (metadata?['duration'] ?? 0) as int;
        final durationLabel = durationSeconds > 0
            ? '${(durationSeconds ~/ 60).toString().padLeft(2, '0')}:${(durationSeconds % 60).toString().padLeft(2, '0')}'
            : '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: thumbUrl.isNotEmpty
                        ? Image.network(
                      thumbUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, __) =>
                          Container(
                            color: Colors.black12,
                          ),
                    )
                        : Container(
                      color: Colors.black26,
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  if (durationLabel.isNotEmpty)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          durationLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                caption,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        );

      case 'document':
        final fileName =
            metadata?['fileName']?.toString() ?? text;
        final fileSize = metadata?['fileSize']?.toString() ?? '';
        final ext =
            metadata?['fileType']?.toString().toUpperCase() ?? '';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.insert_drive_file_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [ext, fileSize].where((s) => s.isNotEmpty).join(' • '),
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case 'location':
        final address =
            metadata?['address']?.toString() ?? text;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                address,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        );

      default:
      // simple text
        return Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
          ),
        );
    }
  }
}
