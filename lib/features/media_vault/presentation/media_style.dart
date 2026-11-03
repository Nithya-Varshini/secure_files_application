import 'package:flutter/material.dart';

import '../domain/media_item.dart';

extension MediaSubjectStyle on MediaSubject {
  IconData get icon => switch (this) {
    MediaSubject.landscape => Icons.landscape_rounded,
    MediaSubject.portrait => Icons.face_rounded,
    MediaSubject.pet => Icons.pets_rounded,
    MediaSubject.food => Icons.restaurant_rounded,
    MediaSubject.travel => Icons.flight_takeoff_rounded,
    MediaSubject.celebration => Icons.cake_rounded,
    MediaSubject.nature => Icons.local_florist_rounded,
  };
}
