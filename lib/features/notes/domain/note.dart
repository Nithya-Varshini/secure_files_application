import 'package:equatable/equatable.dart';

class Note extends Equatable {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
    this.pinned = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime updatedAt;
  final bool pinned;

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  Note copyWith({bool? pinned}) => Note(
    id: id,
    title: title,
    body: body,
    updatedAt: updatedAt,
    pinned: pinned ?? this.pinned,
  );

  @override
  List<Object?> get props => [id, title, body, updatedAt, pinned];
}
