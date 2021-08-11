import 'package:flutter/material.dart';
import 'package:vgbnd/sync/sync.dart';

AppBar buildTopNav(BuildContext context, GlobalKey<ScaffoldState> key) {
  return AppBar(
      elevation: 0,
      title: Row(
        children: [
          Visibility(
              child: Text(
            "Dashboard",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          )),
        ],
      ),
      actions: [SyncButtonWidget()],
      leading: _buildLeading(context, key));
}

Widget _buildLeading(BuildContext context, GlobalKey<ScaffoldState> key) {
  return Stack(
    children: [
      Positioned(
          top: 24,
          left: 46,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), color: Colors.green),
          )),
      Positioned(
          top: 4,
          left: 0,
          child: IconButton(
            icon: Icon(
              Icons.menu,
            ),
            onPressed: () {
              key.currentState?.openDrawer();
            },
          ))
    ],
  );
}

class SyncButtonWidget extends StatefulWidget {
  @override
  _SyncButtonWidgetState createState() => _SyncButtonWidgetState();
}

class _SyncButtonWidgetState extends State<SyncButtonWidget> with SingleTickerProviderStateMixin {
  var _isLoading = false;
  late AnimationController animationController;

  @override
  void initState() {
    super.initState();
    animationController = new AnimationController(
      vsync: this,
      duration: new Duration(seconds: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onPressed = _isLoading
        ? null
        : () {
            _triggerSync();
          };

    return AnimatedBuilder(
      animation: animationController,
      child: IconButton(onPressed: onPressed, icon: Icon(Icons.sync)),
      builder: (context, child) {
        return Transform.rotate(
          angle: animationController.value * 6.3,
          child: child,
        );
      },
    );
  }

  _triggerSync() async {
    setState(() {
      _isLoading = true;
      animationController.repeat();
    });
    await SyncEngine.current().invalidateLocalCache();
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      animationController.stop();
      animationController.reset();
    });
  }
}
