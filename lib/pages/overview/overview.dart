import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/sync/sync.dart';
import 'package:vgbnd/widgets/numeric_stepper_input.dart';

class OverviewPage extends StatelessWidget {

  OverviewPage() : super() {
    print("aaaaaa");
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          SizedBox(
            height: 40,
          ),
          Stack(
            children: [
              SizedBox(
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                ),
                height: 62,
                width: 62,
              ),
              Positioned(top: 3, left: 3, child: FloatingActionButton(onPressed: () {}))
            ],
          ),
          TextButton(
            child: Text("Sync"),
            onPressed: () async {
              final res = await SyncEngine.forAccount(UserAccount.current).pullChanges();
              print("sync done $res");
            },
          ),
          TextButton(
            child: Text("Invalidate"),
            onPressed: () async {
              final res = await SyncEngine.forAccount(UserAccount.current).invalidateLocalCache();
              print("sync done $res");
            },
          ),
          Padding(
            padding: EdgeInsets.all(4),
            child: NumericStepperInput(),
          ),
          Padding(
            padding: EdgeInsets.all(4),
            child: NumericStepperInput(),
          ),
          Padding(
            padding: EdgeInsets.all(4),
            child: NumericStepperInput(),
          ),
          Padding(
            padding: EdgeInsets.all(4),
            child: NumericStepperInput(),
          ),
        ],
      ),
    );
  }
}
