import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/controllers/app_section_controller.dart';
import 'package:vgbnd/controllers/auth_controller.dart';
import 'package:vgbnd/pages/locations/locations_list.dart';
import 'package:vgbnd/sync/sync.dart';
import 'package:vgbnd/widgets/search.dart';

import '../ext.dart';

class AppPageLayout extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool isRoot;

  AppPageLayout(
      {Key? key, required this.title, required this.body, this.actions, this.floatingActionButton, this.isRoot = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isRoot = true;
    final account = AuthController.instance.currentAccount;
    if (account == null) {
      return emptyWidget();
    }

    return Scaffold(
      key: scaffoldKey,
      appBar: _buildTopNav(
        context,
      ),
      drawer: isRoot ? _buildDrawer(context, account) : null,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildDrawer(BuildContext ctx, UserAccount account) {
    final theme = Theme.of(ctx);
    return Drawer(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
            color: theme.primaryColor,
            padding: EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    account.displayName,
                    textAlign: TextAlign.left,
                    style: TextStyle(color: Colors.white),
                  ),
                  Text(
                    account.email,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.white),
                  )
                ],
              ),
            )),
        Column(
          children: AppSection.ALL.map((appSection) => _buildDrawerMenuItem(ctx, appSection)).toList(),
        ),
        Divider(),
        MaterialButton(
            child: Text("Log out", style: TextStyle(color: theme.primaryColor, fontSize: 16), textAlign: TextAlign.start,),
            onPressed: () async {
              await AuthController.instance.logout();
            })
      ],
    ));
  }

  Widget _buildDrawerMenuItem(BuildContext context, AppSection appSection) {
    double size = 24;
    final theme = Theme.of(context);

    return InkWell(
        onTap: () {
          Navigator.pop(context);
          switch (appSection) {
            case AppSection.Locations:
              Get.to(() => LocationsListScreen());
              break;
            case AppSection.Dashboard:
              break;
          }
        },
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Icon(appSection.iconData, size: size, color: theme.primaryColorDark),
            ),
            Text(
              appSection.displayName,
              style: TextStyle(fontSize: 14, color: theme.primaryColor, fontWeight: FontWeight.w500),
            )
          ],
        ));
  }

  PreferredSizeWidget _buildTopNav(BuildContext context) {
    final List<Widget> appBarActions = [];
    if (actions != null) {
      appBarActions.addAll(actions!);
    }
    appBarActions.add(SyncButtonWidget());

    return SearchAppBar(
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: appBarActions,
        leading: Stack(
          children: [
            Positioned(top: 24, left: 46, child: OnlineStateWidget()),
            Positioned(
                top: 4,
                left: 0,
                child: IconButton(
                  icon: Icon(
                    isRoot ? Icons.menu : Icons.arrow_back,
                  ),
                  onPressed: () {
                    if (isRoot) {
                      scaffoldKey.currentState?.openDrawer();
                    } else {
                      Get.back();
                    }
                  },
                ))
          ],
        ));
  }
}

class OnlineStateWidget extends StatelessWidget {
  OnlineStateWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), color: Colors.green),
    );
  }
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
    await SyncController.current().pullChanges();
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
