import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vgbnd/helpers/sql_select_query.dart';
import 'package:vgbnd/pages/locations/locations_list.dart';
import 'package:vgbnd/pages/locations/locations_overview.dart';
import 'package:vgbnd/widgets/app_page_layout.dart';
import 'package:vgbnd/widgets/table_view/table_view.dart';
import 'package:vgbnd/widgets/table_view/table_view_controller.dart';
import 'package:vgbnd/widgets/table_view/table_view_data_source.dart';

class DashboardScreen extends StatelessWidget {
  DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppPageLayout(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildTodaysSales(context),
            SizedBox(
              height: 50,
            ),
            _buildLowestLocationsFillList(context),
          ]),
        ),
      ),
      title: "Dashboard",
      isRoot: true,
    );
  }

  Widget _buildLowestLocationsFillList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Locations",
                  style: _primaryTextStyle(context),
                ),
                Text(
                  "Lowest Percent Fill",
                  style: _hintTextStyle(context),
                )
              ],
            ),
            TextButton(
              child: Text("VIEW ALL"),
              onPressed: () {
                Get.to(() => LocationsListScreen());
              },
            )
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                offset: Offset(0.0, 1.0), //(x,y)
                blurRadius: 1.0,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(4),
            child: TableView(
              shrinkWrap: true,
              headersVisible: false,
              onRowClick: (controller, renderIndex) {
                final locationId = controller.getDatasourceValueAt<int>("id", renderIndex: renderIndex)!;
                Get.to(() => LocationsOverview(
                      locationId: locationId,
                    ));
              },
              controller: TableViewController(SqlQueryDataSource(SqlSelectQuery.from("location_fill")
                ..join("join locations on location_fill.location_id = locations.id")
                ..field("locations.id", "id")
                ..field("locations.location_name", "location_name")
                ..field("location_fill.fill_percent", "fill_percent")
                ..order("fill_percent asc")
                ..limit(10))),
              columns: [
                TableColumn("location_name", label: "Name", sortable: true),
                TableColumn(
                  "fill_percent",
                  label: "Fill",
                  sortable: true,
                  width: 80,
                  contentAlignment: Alignment.centerRight,
                  buildBodyCellFunc: (context, col, controller, index) {
                    var fillPercent =
                        controller.getDatasourceValueAt<num>("fill_percent", renderIndex: index)?.round() ?? 0;
                    return Text("$fillPercent%");
                  },
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildTodaysSales(BuildContext context) {
    final theme = Theme.of(context);

    final valueTextStyle = TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold);
    final labelTextStyle = TextStyle(color: Colors.white, fontSize: 18);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 18,
        ),
        Text(
          "Today's sales",
          textAlign: TextAlign.left,
          style: _primaryTextStyle(context),
        ),
        SizedBox(
          height: 18,
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.primaryColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                offset: Offset(0.0, 1.0), //(x,y)
                blurRadius: 1.0,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text(
                      "48",
                      style: valueTextStyle,
                    ),
                    Text(
                      "Units",
                      style: labelTextStyle,
                    ),
                  ],
                ),
                SizedBox(
                  width: 30,
                ),
                Column(
                  children: [
                    Text(
                      "\$68",
                      style: valueTextStyle,
                    ),
                    Text(
                      "Revenue",
                      style: labelTextStyle,
                    ),
                  ],
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  TextStyle _primaryTextStyle(BuildContext context) {
    return TextStyle(color: Theme.of(context).primaryColorDark, fontSize: 18, fontWeight: FontWeight.w500);
  }

  TextStyle _hintTextStyle(BuildContext context) {
    return TextStyle(color: Theme.of(context).primaryColor, fontSize: 14, fontWeight: FontWeight.normal);
  }
}
