import 'package:equatable/equatable.dart';

enum MediaType { photo, video }

class MediaItem extends Equatable {
  const MediaItem({
    required this.id,
    required this.title,
    required this.type,
    required this.mimeType,
    required this.createdAt,
    required this.sizeBytes,
    this.width,
    this.height,
    this.hasThumbnail = false,
    this.favorite = false,
  });

  final String id;
  final String title;
  final MediaType type;
  final String mimeType;
  final DateTime createdAt;
  final int sizeBytes;
  final int? width;
  final int? height;
  final bool hasThumbnail;
  final bool favorite;

  bool get isVideo => type == MediaType.video;

  /// Seed for the placeholder shown while (or instead of) a thumbnail.
  int get seed => id.hashCode;

  double get aspectRatio =>
      width != null && height != null && height! > 0 ? width! / height! : 4 / 3;

  MediaItem copyWith({bool? favorite}) => MediaItem(
    id: id,
    title: title,
    type: type,
    mimeType: mimeType,
    createdAt: createdAt,
    sizeBytes: sizeBytes,
    width: width,
    height: height,
    hasThumbnail: hasThumbnail,
    favorite: favorite ?? this.favorite,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    type,
    mimeType,
    createdAt,
    sizeBytes,
    width,
    height,
    hasThumbnail,
    favorite,
  ];
}
