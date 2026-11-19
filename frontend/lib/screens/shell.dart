import 'package:flutter/material.dart';
import '../ui.dart';

class ShellTab {
  final String label;
  final IconData icon, activeIcon;
  final Widget page;
  const ShellTab(this.label, this.icon, this.activeIcon, this.page);
}

/// Kerangka navigasi adaptif: bar bawah di HP, rail samping di layar lebar.
class AppShell extends StatelessWidget {
  final String title;
  final List<ShellTab> tabs;
  final int index;
  final ValueChanged<int> onIndex;
  final List<Widget> actions;
  const AppShell({super.key, required this.title, required this.tabs, required this.index, required this.onIndex, this.actions = const []});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, cons) {
        final wide = cons.maxWidth >= 720;
        final i = index >= tabs.length ? 0 : index;
        final page = KeyedSubtree(key: ValueKey('tab$i'), child: tabs[i].page);
        if (!wide) {
          return Scaffold(
            appBar: appBarOf(title, actions: actions),
            body: page,
            bottomNavigationBar: NavigationBar(
              selectedIndex: i,
              onDestinationSelected: onIndex,
              destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.activeIcon, color: kPine), label: t.label)],
            ),
          );
        }
        return Scaffold(
          appBar: appBarOf(title, actions: actions),
          body: Row(children: [
            NavigationRail(
              selectedIndex: i,
              onDestinationSelected: onIndex,
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.white,
              indicatorColor: kMint,
              destinations: [for (final t in tabs) NavigationRailDestination(icon: Icon(t.icon), selectedIcon: Icon(t.activeIcon, color: kPine), label: Text(t.label))],
            ),
            const VerticalDivider(width: 1, color: kLine),
            Expanded(child: page),
          ]),
        );
      });
}
