
import 'package:flutter/material.dart';

class AppFab extends StatelessWidget {
  final List<AppFabMenuItem>? menuItems;
  final IconData? fabIcon;
  final VoidCallback? onTap;
  late final bool enabled;
  late final bool loading;

  AppFab({this.menuItems, this.fabIcon, this.onTap, bool? enabled, bool? loading}) {
    this.enabled = enabled ?? true;
    this.loading = loading ?? false;
    if (this.loading) {
      this.enabled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final menuItems = this.menuItems ?? [];

    final fabIcon = this.fabIcon ?? (menuItems.isNotEmpty ? Icons.menu : null);

    final List<Widget> children = [];

    if (this.loading) {
      children.add(SizedBox(
        child: CircularProgressIndicator(
          strokeWidth: 6,
          color: theme.primaryColorDark,
        ),
        height: 60,
        width: 60,
      ));
    }

    children.add(FloatingActionButton(
      child: Icon(fabIcon),
      onPressed: this.enabled
          ? onTap ??
              () {
            print("no handler");
          }
          : null,
    ));

    if (this.enabled && !this.loading && menuItems.isNotEmpty) {
      children.add(PopupMenuButton<int>(
        onSelected: (value) {
          menuItems[value].onTap();
        },
        child: Container(
          height: 60,
          width: 60,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(60),
          ),
          //child: Icon(Icons.menu, color: Colors.white), <-- You can give your icon here
        ),
        itemBuilder: (context) {
          return menuItems.map((final item) {
            final idx = menuItems.indexOf(item);
            return PopupMenuItem(
              value: idx,
              child: Row(
                children: <Widget>[
                  Icon(
                    item.icon,
                    size: 24,
                    color: theme.primaryColor,
                  ),
                  SizedBox(
                    width: 16,
                  ),
                  Text(
                    item.text,
                    style: TextStyle(color: theme.primaryColor),
                  ),
                ],
              ),
            );
          }).toList();
        },
      ));
    }

    return Stack(children: children);
  }
}

class AppFabMenuItem {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  AppFabMenuItem({required this.text, required this.icon, required this.onTap});
}
