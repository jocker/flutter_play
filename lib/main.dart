import 'package:dynamic_themes/dynamic_themes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vgbnd/pages/splash_screen.dart';

import 'constants/app_theme.dart';
import 'controllers/auth_controller.dart';

void main() {
  AuthController.register();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dark = ThemeData.dark();
    final darkButtonTheme = dark.buttonTheme.copyWith(buttonColor: Colors.grey[700]);
    final darkFABTheme = dark.floatingActionButtonTheme;
    //0a549d
    final themeCollection = ThemeCollection(themes: {
      AppTheme.Blue: _createTheme(ThemeData(primarySwatch: AppTheme.blue, brightness: Brightness.light)),
      AppTheme.Red: ThemeData(primarySwatch: AppTheme.red),
      AppTheme.Green: ThemeData(primarySwatch: AppTheme.green),
      AppTheme.Dark: dark.copyWith(
          accentColor: AppTheme.blue,
          buttonTheme: darkButtonTheme,
          floatingActionButtonTheme: darkFABTheme.copyWith(backgroundColor: AppTheme.blue)),
    });

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeCollection[AppTheme.Blue],
      home: SplashScreen.recoverSession(),
    );
  }

  ThemeData _createTheme(ThemeData theme) {
    return theme.copyWith(
      splashColor: theme.primaryColorLight,
        scaffoldBackgroundColor: Color.lerp(theme.primaryColor, Colors.white, 0.95),
        //inputDecorationTheme: theme.inputDecorationTheme.copyWith(labelStyle: TextStyle(color:Colors.red)),
        textTheme: theme.textTheme
            .apply(bodyColor: theme.primaryColorDark, displayColor: Colors.blue, decorationColor: Colors.red));
  }
}
