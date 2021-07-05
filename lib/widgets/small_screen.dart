import 'package:flutter/material.dart';
import 'package:vgbnd/pages/overview/overview.dart';

class SmallScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      //constraints: BoxConstraints.expand(),
      color: Colors.green,
      child: OverviewPage(),
    );
  }
}
