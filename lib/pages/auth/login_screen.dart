
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:vgbnd/controllers/auth_controller.dart';
import 'package:vgbnd/helpers/form.dart';
import 'package:vgbnd/pages/dashboard/dashboard.dart';
import 'package:vgbnd/pages/splash_screen.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _userName = "";
  String? _passwd = "";
  var _isLoggingIn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Center(
      child: Padding(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
              child: Column(
            children: [
              Image.asset(
                "assets/logos/vagabond_logo_large.png",
                height: 50,
              ),
              SizedBox(
                height: 50,
              ),
              Text(
                "Login to your account",
                style: TextStyle(fontSize: 20),
              ),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    buildTextField(
                      isRequired: true,
                      label: "Username",
                      onSaved: (newValue) {
                        _userName = newValue;
                      },
                      value: 'staging::bonnie@vagabondvending.com',
                    ),
                    buildTextField(
                      obscureText: true,
                      isRequired: true,
                      label: "Password",
                      onSaved: (newValue) {
                        _passwd = newValue;
                      },
                      value: 'bonnierocks',
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 50,
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 30), // double.infinity is the width and 30 is the height
                ),
                child: Text("Sign In"),
                onPressed: _isLoggingIn
                    ? null
                    : () {
                        _submitLogin(context);
                      },
              )
            ],
          ))),
    );
  }

  _submitLogin(BuildContext context) async {
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

    setState(() {
      _isLoggingIn = true;
    });

    final loggedIn = await doX();

    setState(() {
      _isLoggingIn = false;
    });

    if (loggedIn) {
      SplashScreen.openForSync((success) {
        if (success) {}
        Get.offAll(() => DashboardScreen());
      });
    }
  }

  Future<bool> doX() async {
    final resp = await AuthController.instance.login(_userName!, _passwd!);
    if (!resp.success) {
      Fluttertoast.showToast(msg: resp.message ?? "Authentication failure. Please try again.");
      return false;
    }

    return true;
  }
}
