import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class OverviewPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
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

class NumericStepperInput extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _NumericStepperInputState();
  }
}

class _NumericStepperInputState extends State<NumericStepperInput> {
  double? _originalValue, _value;
  bool _isDirty = false;
  bool _isEnabled = true;
  double _widgetHeight = 24;
  TextEditingController _controller = TextEditingController(text: "");
  final _focusNode = FocusNode();

  static final _textInputFilter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9](\.?[0-9]{0,2}?)?'));

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        final newValue = double.tryParse(_controller.text) ?? _originalValue;
        setValue(newValue);
      } else {
        _controller.selection =
            TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var primaryColor = Theme.of(context).primaryColorDark;
    var background = primaryColor.withAlpha(100);

    return Container(
      width: 200,
      child: Row(
        children: [
          _buildButton(context, _StepperButtonType.Remove, (_value ?? 0) > 0),
//          Flexible(child: Text("$value")),
          Expanded(
              child: Container(
            height: _widgetHeight,
            alignment: Alignment.center,
            margin: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
                color: background, borderRadius: BorderRadius.circular(5)),
            child: TextField(
              enabled: _isEnabled,
              textAlign: TextAlign.center,
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[_textInputFilter],
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                filled: false,
                fillColor: background,
                hoverColor: Colors.red,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    width: 0,
                    style: BorderStyle.none,
                  ),
                ),
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
              style: TextStyle(
                  color: primaryColor,
                  fontWeight: _isDirty && !_focusNode.hasFocus
                      ? FontWeight.bold
                      : FontWeight.normal),
            ),
          )),

          _buildButton(context, _StepperButtonType.Add, true)
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext ctx, _StepperButtonType t, bool enabled) {
    var btnColor = Theme.of(context).primaryColorDark;
    enabled = enabled && _isEnabled;
    if (!enabled) {
      btnColor = btnColor.withAlpha(100);
    }

    var icon = t == _StepperButtonType.Add
        ? Icons.add_circle_outline
        : Icons.remove_circle_outline;

    final iconWidget = Icon(
      icon,
      size: _widgetHeight,
      color: btnColor,
    );

    if (!enabled) {
      return iconWidget;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(_widgetHeight),
      onTap: () {
        setState(() {
          this._incBy(t == _StepperButtonType.Add ? 1 : -1);
        });
      },
      child: iconWidget,
    );
  }

  _incBy(int delta) {
    if (_clearFocus()) {
      return;
    }
    this.setValue((_value ?? 0) + delta);
  }

  setValue(double? value) {
    if ((value ?? 0) < 0) {
      value = 0;
    }
    if (value == 0) {
      value = null;
    }

    if (_value != value) {
      setState(() {
        this._controller.text = value == null ? "" : "$value";
        _value = value;
        _clearFocus();

        _isDirty = value != _originalValue;
      });
    }
  }

  bool _clearFocus() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
    _focusNode.dispose();
  }
}

enum _StepperButtonType { Add, Remove }
