import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/import_actions.dart';
import '../../../app/routes.dart';
import '../../../core/state/load_status.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/protection_ring.dart';
import '../../authentication/presentation/session_cubit.dart';
import '../../backup_restore/presentation/backup_cubit.dart';
import '../../files/presentation/files_cubit.dart';
import '../../media_vault/presentation/media_cubit.dart';
import '../../media_vault/presentation/vault_thumbnail.dart';
import '../../media_vault/presentation/media_viewer_page.dart';
import '../../notes/presentation/notes_cubit.dart';
import '../../security_center/domain/security_check.dart';
import '../../settings/presentation/settings_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaCubit>().state;
    final files = context.watch<FilesCubit>().state;
    final notes = context.watch<NotesCubit>().state;
    final loading = media.status != LoadStatus.ready;
    final itemCount = media.items.length + files.files.length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(greeting()),
            actions: [
              IconButton(
                tooltip: 'Lock vault',
                icon: const Icon(Icons.lock_outline_rounded),
                onPressed: () => context.read<SessionCubit>().lock(),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push(Routes.settings),
              ),
              const SizedBox(width: 4),
            ],
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _ProtectionCard(),
            ),
          ),
          const SliverToBoxAdapter(child: _QuickActions()),
          const SliverToBoxAdapter(child: SectionHeader(title: 'Your vault')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            // Fixed height rather than an aspect ratio: on narrow phones a
            // width-derived height was too short for the text (11 px overflow).
            sliver: SliverGrid.list(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 136,
              ),
              children: [
                _CategoryCard(
                  icon: Icons.photo_outlined,
                  label: 'Photos',
                  count: loading ? null : media.photoCount,
                  color: AppColors.photos,
                  onTap: () => context.go(Routes.gallery),
                ),
                _CategoryCard(
                  icon: Icons.videocam_outlined,
                  label: 'Videos',
                  count: loading ? null : media.videoCount,
                  color: AppColors.videos,
                  onTap: () => context.go(Routes.gallery),
                ),
                _CategoryCard(
                  icon: Icons.description_outlined,
                  label: 'Documents',
                  count: files.status == LoadStatus.ready
                      ? files.files.length
                      : null,
                  color: AppColors.documents,
                  onTap: () => context.go(Routes.files),
                ),
                _CategoryCard(
                  icon: Icons.sticky_note_2_outlined,
                  label: 'Notes',
                  count: notes.status == LoadStatus.ready
                      ? notes.notes.length
                      : null,
                  color: AppColors.notes,
                  onTap: () => context.go(Routes.notes),
                ),
              ],
            ),
          ),
          if (media.items.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Recently added',
                actionLabel: 'See all',
                onAction: () => context.go(Routes.gallery),
              ),
            ),
            SliverToBoxAdapter(child: _RecentStrip(media: media)),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: _StorageSummary(
                items: itemCount + notes.notes.length,
                bytes: media.totalBytes + files.totalBytes,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  const _ProtectionCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = context.watch<SessionCubit>().state;
    final settings = context.watch<SettingsCubit>().state;
    final backup = context.watch<BackupCubit>().state;
    final checks = SecurityChecklist.evaluate(
      recoveryVerified: session.recoveryVerified,
      autoLock: settings.autoLock,
      screenshotProtection: settings.screenshotProtection,
      recentBackup: backup.isRecent(DateTime.now()),
    );
    final done = checks.where((c) => c.ok).length;
    final allGood = done == checks.length;

    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push(Routes.security),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              ProtectionRing(
                done: done,
                total: checks.length,
                color: scheme.primary,
                trackColor: scheme.onPrimaryContainer.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allGood ? 'Fully protected' : 'Vault protected',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      allGood
                          ? 'Every protection is switched on.'
                          : '$done of ${checks.length} protections on. '
                                'Tap to review.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickAction(
            icon: Icons.add_photo_alternate_outlined,
            label: 'Photos',
            onTap: () => runImport(context, ImportSource.photos),
          ),
          _QuickAction(
            icon: Icons.upload_file_outlined,
            label: 'Files',
            onTap: () => runImport(context, ImportSource.files),
          ),
          _QuickAction(
            icon: Icons.document_scanner_outlined,
            label: 'Scan',
            onTap: () => runImport(context, ImportSource.scan),
          ),
          _QuickAction(
            icon: Icons.edit_note_outlined,
            label: 'Note',
            onTap: () => runImport(context, ImportSource.note),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Icon and label form one tap target: people tap the word too.
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int? count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      count?.toString() ?? '–',
                      key: ValueKey(count),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentStrip extends StatelessWidget {
  const _RecentStrip({required this.media});

  final MediaState media;

  @override
  Widget build(BuildContext context) {
    final recent = ([
      ...media.items,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt))).take(8).toList();
    final ids = [for (final m in recent) m.id];
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: recent.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => SizedBox.square(
          dimension: 112,
          child: OpenContainer(
            // Root navigator: the opened page covers the bottom navigation bar.
            useRootNavigator: true,
            closedElevation: 0,
            openElevation: 0,
            closedColor: Colors.transparent,
            openColor: Colors.black,
            middleColor: Colors.black,
            closedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            transitionDuration: const Duration(milliseconds: 450),
            openBuilder: (context, _) =>
                MediaViewerPage(ids: ids, initialIndex: i),
            closedBuilder: (context, _) =>
                VaultThumbnail(item: recent[i], borderRadius: 16),
          ),
        ),
      ),
    );
  }
}

class _StorageSummary extends StatelessWidget {
  const _StorageSummary({required this.items, required this.bytes});

  final int items;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.phone_android_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatBytes(bytes)} in your vault',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$items items, stored only on this phone',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
