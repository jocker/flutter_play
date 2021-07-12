import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/sync/constants.dart';
import 'package:vgbnd/sync/sync.dart';
import 'package:vgbnd/widgets/numeric_stepper_input.dart';

class OverviewPageNew extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 1,
      itemBuilder: (context, index) {
        /* return ListTile(
          title: Text('aaaa'),

        );*/
        return Expanded(
            child: Center(
              child: CircularProgressIndicator(),
            ));
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }
}

abstract class DataProvider<T> {
  static const int STATE_NONE = 0,
      STATE_PROVISIONING = 1,
      STATE_PROVISIONED = 2,
      STATE_PROVISION_ERROR = 3;

  final _dataChanged = StreamController<DataProvider<T>>.broadcast();
  int _currentState = STATE_NONE;

  dispose() {
    _dataChanged.close();
  }

  bool _setState(int newState) {
    if (newState != _currentState) {
      _currentState = newState;
      notifyChanged();
      return true;
    }
    return false;
  }

  int get currentState {
    return _currentState;
  }

  T getItemAt(int position);

  int getLoadedItemCount();

  notifyChanged() {
    _dataChanged.add(this);
  }

  StreamSubscription<DataProvider<T>> onStateChanged(void onData(DataProvider<T> source)?,
      {Function? onError, void onDone()?, bool? cancelOnError}) {
    var prevState = _currentState;
    return _dataChanged.stream.listen((event) {
      if (event.currentState != prevState) {
        prevState = event.currentState;
        onData?.call(this);
      }
    }, cancelOnError: cancelOnError, onDone: onDone, onError: onError)
  }


}

class OverviewPage extends StatelessWidget {
  OverviewPage() {
    _doStuff();
  }

  _doStuff() async {
    final t = DateTime
        .now()
        .millisecondsSinceEpoch;
    final cur = await SyncEngine.current().fetchCursor("select * from columns where location_id=?", args: [225941]);
    print("xxxx ${DateTime
        .now()
        .millisecondsSinceEpoch - t}");
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
