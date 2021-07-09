import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/sync/sync.dart';
import 'package:vgbnd/widgets/numeric_stepper_input.dart';

class OverviewPage extends StatelessWidget {
  bool _listening = false;

  OverviewPage() : super() {
    print("aaaaaa");
    print("aaaaaa");

        () async {
      if (_listening) {
        return;
      }
      _listening = true;
      final dbPath = "/data/user/0/com.dtg.vagabond.vgbnd/app_flutter/databases/data_649.db";
      final db = await DbConn.open(dbPath, runMigrations: false);

      /*final values = db.selectOne("select * from columns limit 1");
      final int id = db.selectValue("select id from locations limit 1;");
      final strId = db.selectValue<String>("select id from locations limit 1;");*/
      final values = db.selectOne("select * from columns where id=615586");
      final coil = Coil.schema.instantiate(values);
      final v = coil.dumpValues();
      print("xxxxx");

      final stream = await SyncEngine.forAccount(UserAccount.current).watchSchemas(SyncEngine.SYNC_SCHEMAS);
      StreamSubscription? subscription;
      subscription = stream.listen((version) {
        print("SCHEMA CHANGED $version");
        //subscription?.cancel();
      });
    }();
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
            child: Text("CREATE"),
            onPressed: () async {
              final api = Api(UserAccount.current);
              final createResp = await api.createSchemaObject("locations", {"location_name": "TEST"});
              final created = createResp.body?.toList().first.entries().toList().first.toSyncObject();
              final deleteResp = await api.deleteSchemaObject("locations", created!.getId());
              final l = createResp.body?.toList().first.entries().toList().first.toSyncObject();
              print(l);
            },
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
