import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync.dart';
import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/widgets/picker/sync_object_list_view.dart';

enum InputType { Text, Decimal, Integer }

const FIELD_VALIDATOR_PRESENCE = 1 << 0;

Widget buildTextField({required String label,
  required String? value,
  InputType? inputType,
  FormFieldSetter<String>? onSaved,
  int? validatorFlags,
  bool obscureText = false,
  bool? isRequired}) {
  inputType ??= InputType.Text;

  final ctrl = TextEditingController();
  ctrl.value = TextEditingValue(
    text: value ?? "",
  );
  ctrl.selection = TextSelection.fromPosition(
    TextPosition(offset: ctrl.text.length),
  );

  List<TextInputFormatter> inputFormatters = [];
  TextInputType? keyboardType;

  switch (inputType) {
    case InputType.Decimal:
      inputFormatters.add(DecimalTextInputFormatter(decimalRange: 2));
      keyboardType = TextInputType.numberWithOptions(decimal: true);
      break;
    case InputType.Integer:
      keyboardType = TextInputType.numberWithOptions(decimal: true);
      break;
    default:
      break;
  }

  return TextFormField(
      obscureText: obscureText,
      textInputAction: TextInputAction.next,
      controller: ctrl,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.only(bottom: 8, top: 24),
        alignLabelWithHint: true,
      ),
      validator: (value) {
        return _runValidators(value, validatorFlags ?? 0);
      },
      onSaved: onSaved);
}

Widget buildRefSchemaField({required SyncSchema schema, required String label, required int? id, FormFieldSetter<
    int?>? onSaved, String? pickWindowTitle}) {
  return SchemaRefTextField(
    pickWindowTitle: pickWindowTitle,
    objectSchema: schema,
    objectId: id,
    label: label,
    onSaved: onSaved,
  );
}

class DecimalTextInputFormatter extends TextInputFormatter {
  DecimalTextInputFormatter({this.decimalRange}) : assert(decimalRange == null || decimalRange > 0);

  final int? decimalRange;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, // unused.
      TextEditingValue newValue,) {
    TextSelection newSelection = newValue.selection;
    String truncated = newValue.text;

    if (decimalRange != null) {
      String value = newValue.text;

      if (value.contains(".") && value
          .substring(value.indexOf(".") + 1)
          .length > decimalRange!) {
        truncated = oldValue.text;
        newSelection = oldValue.selection;
      } else if (value == ".") {
        truncated = "0.";
        newSelection = newValue.selection.copyWith(
          baseOffset: min(truncated.length, truncated.length + 1),
          extentOffset: min(truncated.length, truncated.length + 1),
        );
      }

      return TextEditingValue(
        text: truncated,
        selection: newSelection,
        composing: TextRange.empty,
      );
    }
    return newValue;
  }
}

class SchemaRefTextField extends StatefulWidget {
  final String label;
  final String? pickWindowTitle;
  int? objectId;

  final SyncSchema objectSchema;
  final FormFieldSetter<int?>? onSaved;

  SchemaRefTextField(
      {Key? key, required this.objectSchema, required this.label, required this.objectId, this.onSaved, this.pickWindowTitle})
      : super(key: key);

  @override
  _SchemaRefTextFieldState createState() {
    return _SchemaRefTextFieldState();
  }
}

class _SchemaRefTextFieldState extends State<SchemaRefTextField> {
  final _fieldController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final objectId = this.widget.objectId ?? 0;

    if (objectId != 0) {
      scheduleMicrotask(() async {
        final obj = (await SyncController.current().loadObject(widget.objectSchema, id: objectId));
        setState(() {
          _fieldController.value = TextEditingValue(text: obj.getDisplayName() ?? "");
        });
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      textInputAction: TextInputAction.next,
      controller: _fieldController,
      readOnly: true,
      onTap: () async {
        final SyncObject? v = await SyncObjectListView.pickOne(widget.objectSchema, title: this.widget.pickWindowTitle);
        if (v != null) {
          _fieldController.value = TextEditingValue(text: v.getDisplayName() ?? "");
          setState(() {
            widget.objectId = v.getId();
          });
        }
        FocusScope.of(context).unfocus();
      },
      decoration: InputDecoration(
          contentPadding: const EdgeInsets.only(bottom: 2, top: 24),
          alignLabelWithHint: true,
          //isDense: true,
          fillColor: Colors.blue,
          labelText: this.widget.label,
          suffixIcon: Padding(
            padding: EdgeInsets.only(top: 24),
            child: Icon(Icons.arrow_drop_down),
          )),
      validator: (value) {},
      onSaved: (newValue) {
        final onSaved = widget.onSaved;
        if (onSaved != null) {
          onSaved(this.widget.objectId);
        }
      },
    );
  }
}


_runValidators(String? value, int validators) {
  if (validators & FIELD_VALIDATOR_PRESENCE == FIELD_VALIDATOR_PRESENCE) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    return null;
  }
}