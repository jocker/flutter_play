import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CaseUnitStepperInput extends StatefulWidget {
  late final int caseSize;
  late final int? initialUnitCount;
  late final int? unitCount;
  late final bool showCases;
  final int id;
  late final ValueChanged<int?>? onChanged;
  late final int minValue;

  CaseUnitStepperInput(this.id,
      {Key? key, int? caseSize, int? initialUnitCount, int? unitCount, bool? showCases, int? minValue, this.onChanged})
      : super(key: key) {
    this.caseSize = caseSize ?? 1;
    this.initialUnitCount = initialUnitCount;
    this.unitCount = unitCount;
    this.showCases = showCases ?? false;
    this.minValue = minValue ?? 1;
  }

  @override
  State<StatefulWidget> createState() {
    return _CaseUnitStepperInputState();
  }
}

class _CaseUnitStepperInputState extends State<CaseUnitStepperInput> {
  int? _unitCount;
  bool _isDirty = false;
  bool _isEnabled = true;
  bool _showCases = false;
  double _widgetHeight = 28;
  TextEditingController _controller = TextEditingController(text: "");
  final _focusNode = FocusNode();

  static final _floatTextInputFilter = FilteringTextInputFormatter.allow(RegExp(r'[0-9](\.?[0-9]{0,2}?)?'));
  static final _intTextInputFilter = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));

  @override
  void initState() {
    super.initState();

    _showCases = widget.showCases;

    this._applyUnitCount(widget.unitCount, false);
    setState(() {});

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        final rawUnitCount = double.tryParse(_controller.text);
        int? newUnitCount;
        if (rawUnitCount != null) {
          newUnitCount = (_showCases ? rawUnitCount * widget.caseSize : rawUnitCount).toInt();
        }
        setUnitCount(newUnitCount);
      } else {
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var primaryColor = Theme.of(context).primaryColor;
    var background = Theme.of(context).primaryColorLight;

    return Container(
      width: 200,
      child: Row(
        children: [
          _buildButton(context, _StepperButtonType.Remove, (_unitCount ?? 0) > 0),
//          Flexible(child: Text("$value")),
          Expanded(
              child: Container(
            height: _widgetHeight,
            alignment: Alignment.center,
            margin: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(2)),
            child: TextField(
              enabled: _isEnabled,
              textAlign: TextAlign.center,
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[_showCases ? _floatTextInputFilter : _intTextInputFilter],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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
                  fontWeight: _isDirty && !_focusNode.hasFocus ? FontWeight.bold : FontWeight.normal),
            ),
          )),

          _buildButton(context, _StepperButtonType.Add, true)
        ],
      ),
    );
  }

  setShowCases(bool showCases) {
    if (_showCases != showCases) {
      setState(() {
        _showCases = showCases;
      });
    }
  }

  Widget _buildButton(BuildContext ctx, _StepperButtonType t, bool enabled) {
    var btnColor = Theme.of(context).primaryColor;
    enabled = enabled && _isEnabled;
    if (!enabled) {
      btnColor = btnColor.withAlpha(100);
    }

    var icon = t == _StepperButtonType.Add ? Icons.add_circle_outline : Icons.remove_circle_outline;

    final iconWidget = Icon(
      icon,
      size: _widgetHeight * 0.8,
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

  _incBy(int direction) {
    if (_clearFocus()) {
      return;
    }
    if (_showCases) {
      final currentCases = _getCases(_unitCount);
      if (currentCases == null) {
        if (direction > 0) {
          setUnitCount(widget.caseSize);
        }
      } else if (currentCases > 0) {
        int nextCaseCount = 0;
        if (direction > 0) {
          nextCaseCount = currentCases.ceil();
        } else {
          nextCaseCount = currentCases.floor();
        }
        if (currentCases != nextCaseCount) {
          setUnitCount(nextCaseCount * widget.caseSize);
        } else {
          setUnitCount((nextCaseCount + direction) * widget.caseSize);
        }
      }
    } else {
      this.setUnitCount((_unitCount ?? 0) + direction);
    }
  }

  double? _getCases(int? unitCount) {
    final unitCount = _unitCount?.toDouble();
    if (unitCount == null) {
      return null;
    }
    return (unitCount / widget.caseSize * 100).roundToDouble() / 100;
  }

  setUnitCount(
    int? unitCount,
  ) {
    unitCount = _sanitizeUnitCount(unitCount);

    if (_unitCount != unitCount) {
      setState(() {
        _applyUnitCount(unitCount, true);
      });
      final onChanged = widget.onChanged;
      if (onChanged != null) {
        onChanged(unitCount);
      }
    }
  }

  _applyUnitCount(int? unitCount, bool fromUser) {
    unitCount = _sanitizeUnitCount(unitCount);
    String text = "";
    _unitCount = unitCount;
    if (_showCases) {
      final caseCount = _getCases(unitCount) ?? 0;
      if (caseCount == 0) {
        text = "";
      } else {
        text = caseCount.toString();
      }
    } else if (unitCount != null) {
      text = unitCount.toString();
    } else {
      text = "";
    }

    _controller.text = text;

    _clearFocus();

    _isDirty = _unitCount != widget.initialUnitCount;
  }

  int? _sanitizeUnitCount(int? unitCount) {
    final minValue = widget.minValue;
    if ((unitCount ?? minValue-1) < minValue) {
      unitCount = null;
    }
    return unitCount;
  }

  clear() {
    setUnitCount(null);
  }

  reset() {
    setUnitCount(widget.initialUnitCount);
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
