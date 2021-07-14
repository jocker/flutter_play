import 'package:flutter/material.dart';

AppBar buildTopNav(BuildContext context, GlobalKey<ScaffoldState> key) {
  return AppBar(
      elevation: 0,
      title: Row(
        children: [
          Visibility(
              child: Text(
            "Dashboard",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          )),

        ],
      ),
      leading: _buildLeading(context, key));
}

Widget _buildLeading(BuildContext context, GlobalKey<ScaffoldState> key) {
  return Stack(
    children: [
      Positioned(
          top: 24,
          left: 46,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), color: Colors.green),
          )),
      Positioned(
          top: 4,
          left: 0,
          child: IconButton(
            icon: Icon(
              Icons.menu,
            ),
            onPressed: () {
              key.currentState?.openDrawer();
            },
          ))
    ],
  );
}
