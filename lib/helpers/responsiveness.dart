import 'package:flutter/material.dart';

const int LARGE_SCREEN_SIZE = 1366,
    MEDIUM_SCREEN_SIZE = 768,
    SMALL_SCREEN_SIZE = 560,
    CUSTOM_SCREEN_SIZE = 1100;

class ScreenSize {
  final int intValue;

  const ScreenSize({required this.intValue});

  static const Large = ScreenSize(intValue: LARGE_SCREEN_SIZE);
  static const Medium = ScreenSize(intValue: MEDIUM_SCREEN_SIZE);
  static const Small = ScreenSize(intValue: SMALL_SCREEN_SIZE);
  static const Custom = ScreenSize(intValue: CUSTOM_SCREEN_SIZE);

  static final _sortedValues =
      List.unmodifiable([Small, Medium, Custom, Large]);

  static ScreenSize of(BuildContext context) {
    var size = MediaQuery.of(context).size.width;

    return _sortedValues.firstWhere(
      (element) => element.intValue > size,
      orElse: () => ScreenSize.Large,
    );
  }
}

class ResponsiveWidget extends StatelessWidget {
  final Map<ScreenSize, Widget> _widgetsMap = Map();
  final Widget Function(ScreenSize size) widgetFactory;

  ResponsiveWidget({required this.widgetFactory}) : super();

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(builder: (context, constraints) {
      return this._getOrCreateWidget(ScreenSize.of(context));
    });

  }

  Widget _getOrCreateWidget(ScreenSize size) {
    if (!this._widgetsMap.containsKey(size)) {
      this._widgetsMap[size] = this.widgetFactory(size);
    }
    return this._widgetsMap[size]!;
  }
}
