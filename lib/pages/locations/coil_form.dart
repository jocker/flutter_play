
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:vgbnd/helpers/form.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/models/product.dart';
import 'package:vgbnd/sync/sync.dart';
import 'package:vgbnd/widgets/app_fab.dart';

import '../../ext.dart';

class CoilForm extends StatefulWidget {
  static Future<Coil?> edit(Coil coil) async {
    final lv = CoilForm(coil);

    return await Get.to(lv);
  }

  final Coil coil;

  CoilForm(this.coil);

  @override
  _CoilFormState createState() => _CoilFormState();
}

class _CoilFormState extends State<CoilForm> {
  final _formKey = GlobalKey<FormState>();

  var _isLoading = false;

  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(this.widget.coil.isNewRecord() ? "New Coil" : "Edit Coil")),
        floatingActionButton: AppFab(
          loading: _isLoading,
          fabIcon: Icons.check,
          onTap: () {
            final state = _formKey.currentState;
            if (state == null) {
              return;
            }
            if (!state.validate()) {
              Fluttertoast.showToast(msg: "Some fields are invalid");
              return;
            }
            state.save();

            FocusScopeNode currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus) {
              currentFocus.focusedChild?.unfocus();
            }

            _submitValues();
          },
        ),
        body: Padding(
            padding: EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    buildRefSchemaField(
                      pickWindowTitle: "Choose Product",
                      label: "Product",
                      schema: Product.schema,
                      id: this.widget.coil.productId,
                      onSaved: (newValue) {
                        this.widget.coil.productId = newValue;
                      },
                    ),
                    buildTextField(
                      label: "Coil Name",
                      value: this.widget.coil.displayName,
                      onSaved: (newValue) {
                        this.widget.coil.displayName = newValue;
                      },
                    ),
                    buildTextField(
                      label: "Source Coil",
                      value: this.widget.coil.columnName,
                      onSaved: (newValue) {
                        this.widget.coil.columnName = newValue;
                      },
                    ),
                    buildTextField(
                      label: "Tray",
                      value: this.widget.coil.trayId?.toString(),
                      onSaved: (newValue) {
                        this.widget.coil.trayId = int.tryParse(newValue ?? "");
                      },
                    ),
                    buildTextField(
                      label: "Par Value",
                      value: this.widget.coil.capacity?.toString(),
                      onSaved: (newValue) {
                        this.widget.coil.capacity = int.tryParse(newValue ?? "");
                      },
                    ),
                    buildTextField(
                      label: "Coil Capacity",
                      value: this.widget.coil.maxCapacity?.toString(),
                      onSaved: (newValue) {
                        this.widget.coil.maxCapacity = int.tryParse(newValue ?? "");
                      },
                    ),
                    buildTextField(
                      label: "Current Stock",
                      value: this.widget.coil.lastFill?.toString(),
                      onSaved: (newValue) {
                        this.widget.coil.lastFill = int.tryParse(newValue ?? "");
                      },
                    ),
                    buildTextField(
                      label: "Set Price",
                      value: this.widget.coil.setPrice?.toString(),
                      inputType: InputType.Decimal,
                      validatorFlags: FIELD_VALIDATOR_PRESENCE,
                      onSaved: (newValue) {
                        this.widget.coil.setPrice = double.tryParse(newValue ?? "");
                      },
                    ),
                    verticalFabSpacer()
                  ],
                ),
              ),
            )));
  }

  _submitValues() async {
    setState(() {
      _isLoading = true;
    });

    final res = await SyncController.current().upsertObject(this.widget.coil);
    if (!res.isSuccessful) {
      var msg = res.errorMessages().join("\n");
      if (msg == "") {
        msg = "Unexpected error";
      }
      Fluttertoast.showToast(msg: msg);
      setState(() {
        _isLoading = false;
      });
      return;
    }
    Get.back(result: this.widget.coil);
  }
}
