import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vgbnd/controllers/auth_controller.dart';
import 'package:vgbnd/ext.dart';
import 'package:vgbnd/pages/auth/login_screen.dart';
import 'package:vgbnd/pages/dashboard/dashboard.dart';
import 'package:vgbnd/sync/sync.dart';

enum _SplashAction { RecoverSession, Sync }

class SplashScreen extends StatelessWidget {
  final Action1<bool> onActionCompleted;

  SplashScreen({Key? key, required this.onActionCompleted, required _SplashAction action}) : super(key: key) {
    switch (action) {
      case _SplashAction.RecoverSession:
        _recoverSession();
        break;
      case _SplashAction.Sync:
        _triggerSync();
        break;
      default:
        scheduleMicrotask(() {
          onActionCompleted(false);
        });
        break;
    }
  }

  static Widget recoverSession() {
    return SplashScreen(
      action: _SplashAction.RecoverSession,
      onActionCompleted: (success) async{
        if(success){
          final success = await SyncController.forAccount(AuthController.instance.currentAccount!).pullChanges();
          Get.offAll(() => DashboardScreen());
        }else{
          Get.offAll(() => LoginScreen());
        }
      },
    );
  }

  static openForSync(Action1<bool> onSyncCompleted) async {
    Get.offAll(SplashScreen(
      action: _SplashAction.Sync,
      onActionCompleted: onSyncCompleted,
    ));
  }

  _triggerSync() async {
    final account = AuthController.instance.currentAccount;
    var success = false;
    if (account != null) {
      success = await SyncController.forAccount(account).pullChanges();
    }
    this.onActionCompleted(success);
  }

  _recoverSession() async {
    final success = await AuthController.instance.recoverSession();
    this.onActionCompleted(success);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
              child: SizedBox(
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: Color(0xFF0063BE),
            ),
            height: 60,
            width: 60,
          )),
          Center(
            child: Image.asset(
              "assets/logos/logo.png",
              width: 55,
              height: 55,
            ),
          )
        ],
      ),
    );
  }
}
