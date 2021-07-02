import 'package:flutter/material.dart';
import 'package:vgbnd/constants/styles.dart';
import 'package:vgbnd/helpers/responsiveness.dart';

AppBar buildTopNav(BuildContext context, GlobalKey<ScaffoldState> key) {
  return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Visibility(
              child: Text(
            "Dashboard",
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: lightGrey),
          )),
          Expanded(child: Container()),
          IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.settings,
                color: dark.withOpacity(.7),
              )),
          Stack(
            children: [
              IconButton(
                color: dark.withOpacity(.7),
                icon: Icon(Icons.notifications),
                onPressed: () {},
              ),
              Positioned(
                  top: 9,
                  left: 9,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: Colors.red),
                  ))
            ],
          ),
          //divider
          Container(
            width: 1,
            height: 22,
            color: lightGrey,
          ),
          Text(
            "User Name",
            style: TextStyle(color: lightGrey),
          ),
          Container(
            width: 16,
          ),
          Container(
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(30)),
            child: Container(
              margin: EdgeInsets.all(2),
              padding: EdgeInsets.all(2),
              child: CircleAvatar(
                backgroundColor: light,
                child: Icon(
                  Icons.person_outline,
                  color: dark,
                ),
              ),
            ),
          )
        ],
      ),
      iconTheme: IconThemeData(color: dark),
      leading: ScreenSize.of(context) == ScreenSize.Small
          ? _buildSmall(context, key)
          : _buildLarge(context, key));
}

Widget _buildLarge(BuildContext context, GlobalKey<ScaffoldState> key) {

  return Container(
    padding: EdgeInsets.only(left: 16),
    child: Image.asset(
      "assets/logos/logo.png",
      width: 14,
    ),
  );
}

Widget _buildSmall(BuildContext context, GlobalKey<ScaffoldState> key) {
  return IconButton(
    icon: Icon(
      Icons.menu,
      color: Colors.black,
    ),
    onPressed: () {
      key.currentState?.openDrawer();
    },
  );
}
