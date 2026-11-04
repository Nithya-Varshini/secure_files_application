import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom navigation for the four main areas of the vault.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    // Android Back on Gallery / Files / Notes returns to Home; only Back on
    // Home closes the app. Without this, a tab's root page has nothing to
    // pop, so go_router hands Back to the system and the app closes at once.
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(0);
      },
      child: _scaffold(),
    );
  }

  Widget _scaffold() {
    return Scaffold(
      // Each tab has its own ScaffoldMessenger (see `_tab` in router.dart).
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
        // TickerMode wraps only the tab's content. If it wrapped the fade
        // too, the outgoing tab's fade-out would freeze at full opacity and
        // keep covering the tab underneath.
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: duration,
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: active ? 1 : 0.98,
            duration: duration,
            curve: Curves.easeOut,
            child: TickerMode(enabled: active, child: child),
          ),
        ),
      ),
    );
  }
}
