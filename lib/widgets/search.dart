import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vgbnd/ext.dart';

class SearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;
  final Action1<String>? onSearchTextChanged;

  SearchAppBar({Key? key, this.leading, this.title, this.actions, this.onSearchTextChanged}) : super(key: key);

  @override
  _SearchAppBarState createState() {
    return _SearchAppBarState();
  }

  @override
  Size get preferredSize => Size.fromHeight(56.0);
}

abstract class _SearchTextController {
  setSearchText(String text);

  clearSearchText();

  Stream<String> onSearchTextChanged();

  cancelSearch();
}

class _SearchAppBarState extends State<SearchAppBar> implements _SearchTextController {
  bool _inSearchMode = false;
  final _searchStreamController = StreamController<String>();
  late final Stream<String> _searchStreamText;

  @override
  void initState() {
    _searchStreamText = _searchStreamController.stream.asBroadcastStream();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _searchStreamController.close();
  }

  @override
  Widget build(BuildContext context) {
    return _buildChild(context);
  }

  Widget _buildChild(BuildContext context) {
    if (_inSearchMode) {
      return SearchWidget(this);
    }

    final List<Widget> actions = [];
    actions.addAll(widget.actions ?? []);
    if (widget.onSearchTextChanged != null) {
      actions.add(IconButton(
        icon: Icon(Icons.search),
        onPressed: () {
          setState(() {
            _inSearchMode = true;
          });
        },
      ));
    }

    return AppBar(
      elevation: 0,
      title: this.widget.title,
      leading: this.widget.leading,
      actions: actions,
    );
  }

  @override
  clearSearchText() {
    setSearchText("");
  }

  @override
  Stream<String> onSearchTextChanged() {
    return _searchStreamText;
  }

  @override
  setSearchText(String text) {
    _searchStreamController.sink.add(text);
    final onSearchTextChanged = this.widget.onSearchTextChanged;
    if (onSearchTextChanged != null) {
      onSearchTextChanged(text);
    }
  }

  @override
  cancelSearch() {
    setSearchText("");
    setState(() {
      _inSearchMode = false;
    });
  }
}

class SearchWidget extends StatelessWidget {
  Color? foregroundColor = Colors.red;
  TextStyle? searchTextStyle;

  late final _SearchTextController _controller;

  SearchWidget(this._controller);

  @override
  Widget build(BuildContext context) {
    // to handle notches properly
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;
    final colorScheme = theme.colorScheme;

    this.foregroundColor = appBarTheme.foregroundColor ??
        (colorScheme.brightness == Brightness.dark ? colorScheme.onSurface : colorScheme.onPrimary);

    searchTextStyle = appBarTheme.textTheme?.subtitle1 ?? theme.primaryTextTheme.subtitle1;

    return Container(
      color: theme.appBarTheme.backgroundColor ?? theme.primaryColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _buildBackButton(),
              _buildTextField(),
              _buildClearButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClearButton() {
    return StreamBuilder<String>(
      stream: this._controller.onSearchTextChanged(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.isEmpty != false) return emptyWidget();
        return IconButton(
          icon: Icon(
            Icons.close,
            color: foregroundColor,
          ),
          onPressed: _controller.clearSearchText,
        );
      },
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: foregroundColor),
      onPressed: () {
        _controller.cancelSearch();
      },
    );
  }

  Widget _buildTextField() {
    return Expanded(
      child: StreamBuilder<String>(
        stream: this._controller.onSearchTextChanged(),
        builder: (context, snapshot) {
          TextEditingController controller = _getController(snapshot);
          return TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: "Search...",
            ),
            style: searchTextStyle,
            cursorColor: searchTextStyle?.color,
            onChanged: _controller.setSearchText,
          );
        },
      ),
    );
  }

  TextEditingController _getController(AsyncSnapshot<String> snapshot) {
    final controller = TextEditingController();
    controller.value = TextEditingValue(text: snapshot.data ?? '');
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
    return controller;
  }
}

enum SearchBarEventType { TextChanged, Open, Close }
