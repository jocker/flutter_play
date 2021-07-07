import 'package:flutter/material.dart';
import 'package:vgbnd/data/db.dart';
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
          TextButton(
            child: Text("Trigger"),
            onPressed: () {
              DbConn.open("local.db").then((db) => {
                SyncEngine(db).sync()
            });
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
