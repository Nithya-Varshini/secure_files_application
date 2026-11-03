import 'package:equatable/equatable.dart';

enum MediaType { photo, video }

/// What a sample image depicts; drives placeholder artwork only.
enum MediaSubject {
  landscape,
  portrait,
  pet,
  food,
  travel,
  celebration,
  nature,
}

class MediaItem extends Equatable {
  const MediaItem({
    required this.id,
    required this.title,
    required this.type,
    required this.subject,
    required this.album,
    required this.createdAt,
    required this.sizeBytes,
    required this.seed,
    this.duration,
    this.favorite = false,
  });

  final String id;
  final String title;
  final MediaType type;
  final MediaSubject subject;
  final String album;
  final DateTime createdAt;
  final int sizeBytes;

  /// Seed for placeholder artwork until real thumbnails exist.
  final int seed;
  final Duration? duration;
  final bool favorite;

  bool get isVideo => type == MediaType.video;

  MediaItem copyWith({bool? favorite}) => MediaItem(
    id: id,
    title: title,
    type: type,
    subject: subject,
    album: album,
    createdAt: createdAt,
    sizeBytes: sizeBytes,
    seed: seed,
    duration: duration,
    favorite: favorite ?? this.favorite,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    type,
    subject,
    album,
    createdAt,
    sizeBytes,
    seed,
    duration,
    favorite,
  ];
}
