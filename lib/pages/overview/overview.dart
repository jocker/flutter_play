
import 'package:flutter/material.dart';
import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/sync/sync.dart';


class OverviewPage extends StatelessWidget {
  OverviewPage() {
    _doStuff();
  }

  _doStuff() async {
    final t = DateTime.now().millisecondsSinceEpoch;
    final cur = await SyncEngine.current().select(
        "select * from columns where location_id=? order by coalesce(tray_id, 99999), column_name",
        args: [225941]);
    print("xxxx ${DateTime.now().millisecondsSinceEpoch - t}");
    print("done");
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
