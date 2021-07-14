import 'package:flutter/material.dart';
import 'package:vgbnd/pages/locations/locations_overview.dart';

class SmallScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints.expand(),
      child: LocationsOverview(),
    );
  }
}
