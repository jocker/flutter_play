import 'package:flutter/material.dart';
import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/sync/sync.dart';

class OverviewPage extends StatelessWidget {
  OverviewPage() {
    _doStuff();
  }

  _doStuff() async {}

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          SizedBox(
            height: 40,
          ),
          TextButton(
            child: Text("UPDATE LOCATION"),
            onPressed: () async {

              final loc = (await SyncEngine.current().loadObject(Location.schema, id: 234934))!;
              loc.locationName = "Loc ${DateTime.now().millisecondsSinceEpoch}";

              final x = await SyncEngine.current().mutateObject(loc, SyncObjectMutationType.Update);
              print("fone");
            },
          ),
          TextButton(
            child: Text("CREATE LOCATION"),
            onPressed: () async {
              final loc = new Location();
              loc.locationName = "test sync";

              final x = await SyncEngine.current().mutateObject(loc, SyncObjectMutationType.Create);
              print("fone");
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
        ],
      ),
    );
  }
}
