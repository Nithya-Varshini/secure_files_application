import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/gradient_thumb.dart';
import '../domain/media_item.dart';
import 'media_cubit.dart';

/// Decrypts and shows an item's thumbnail; a soft gradient stands in while
/// it loads and for items without one (videos, undecodable formats).
class VaultThumbnail extends StatelessWidget {
  const VaultThumbnail({super.key, required this.item, this.borderRadius = 10});

  final MediaItem item;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = GradientThumb(
      seed: item.seed,
      icon: item.isVideo ? Icons.play_circle_outline_rounded : null,
      borderRadius: borderRadius,
    );
    if (!item.hasThumbnail) return placeholder;

    return FutureBuilder<Uint8List?>(
      future: context.read<MediaCubit>().thumbnail(item.id),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: bytes == null
              ? placeholder
              : ClipRRect(
                  key: const ValueKey('image'),
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    gaplessPlayback: true,
                  ),
                ),
        );
      },
    );
  }
}
