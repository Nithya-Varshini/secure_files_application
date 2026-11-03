import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom navigation for the four main areas of the vault.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // Tapping the current tab again returns it to its first screen.
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library_rounded),
            label: 'Gallery',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Files',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined),
            selectedIcon: Icon(Icons.sticky_note_2_rounded),
            label: 'Notes',
          ),
        ],
      ),
    );
  }
}

/// Keeps every tab alive (its scroll position and state) but cross-fades
/// between them instead of switching abruptly.
class FadingBranchContainer extends StatelessWidget {
  const FadingBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var i = 0; i < children.length; i++)
          _Branch(active: i == currentIndex, child: children[i]),
      ],
    );
  }
}

class _Branch extends StatelessWidget {
  const _Branch({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 260);
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: TickerMode(
          enabled: active,
          child: AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: duration,
            curve: Curves.easeOut,
            child: AnimatedScale(
              scale: active ? 1 : 0.98,
              duration: duration,
              curve: Curves.easeOut,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
