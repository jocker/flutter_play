import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/helpers/sql_select_query.dart';
import 'package:vgbnd/widgets/table_view/table_view.dart';
import 'package:vgbnd/widgets/table_view/table_view_controller.dart';
import 'package:vgbnd/widgets/table_view/table_view_data_source.dart';

class LocationsList extends StatefulWidget {
  LocationsList({Key? key}) : super(key: key);

  @override
  _LocationsListState createState() {
    return _LocationsListState();
  }
}

class _LocationsListState extends State<LocationsList> {
  var _isInitialized = false;
  final controller = LocationListTableController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TableView(columns: [
      TableColumn("location_name", label: "Name", sortable: true),
      TableColumn(
        "fill_percent",
        label: "Fill",
        sortable: true,
        width: 80,
        contentAlignment: Alignment.centerRight,
        buildBodyCellFunc: (context, col, controller, index) {
          var fillPercent = controller.getDatasourceValueAt<num>("fill_percent", renderIndex: index)?.round() ?? 0;
          return Text("$fillPercent%");
        },
      ),
    ], controller: controller);
  }
}

class LocationListDatasource extends SqlQueryDataSource {
  LocationListDatasource()
      : super(SqlSelectQuery.from("location_fill")
    ..join("join locations on location_fill.location_id = locations.id")
    ..field("locations.id", "id")..field("locations.location_name", "location_name")..field(
        "location_fill.fill_percent", "fill_percent"), useSnapshot: true);
}

class LocationListTableController extends TableViewController {
  LocationListTableController() : super(LocationListDatasource());

  @override
  bool setSortDirection(TableColumn col, SortDirection dir) {
    if (super.setSortDirection(col, dir)) {
      this.dataSource.setCriteria(TableViewDataFilterCriteria(sortBy: {col.key: dir}));
      return true;
    }
    return false;
  }
}

class LocationListPageController extends GetxController {
  static register() {
    Get.lazyPut(() => LocationListPageController());
  }

  final dataSource = LocationListDatasource();

  LocationListPageController get instance {
    return Get.find();
  }
}
