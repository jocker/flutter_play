import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/pages/auth/login_screen.dart';
import 'package:vgbnd/sync/sync.dart';

class AuthResponse {
  final bool success;
  final String? message;
  final UserAccount? account;

  AuthResponse({required this.success, this.message, this.account});
}

class AuthController extends GetxController {
  static const String ACCOUNT_PREFS_KEY = "_account";
  static const String ENV_DELIMITER = "::";

  static register() {
    Get.put(AuthController());
  }

  UserAccount? _currentAccount;

  UserAccount? get currentAccount {
    return _currentAccount;
  }

  static AuthController get instance {
    return Get.find();
  }

  Future<bool> recoverSession() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedAccount = prefs.getString(ACCOUNT_PREFS_KEY);
    UserAccount? account;
    if (encodedAccount != null) {
      try {
        account = UserAccount.fromJson(jsonDecode(encodedAccount));
      } catch (e) {}
    }
    if (account != null) {
      final authResp = await login(account.email, account.password, appEnv: account.env);
      if (authResp.success) {
        await _setCurrentAccount(account, persistAccount: false);
        return true;
      }
    }
    return false;
  }

  Future<bool> logout() async {
    final account = _currentAccount;
    final loggedOut = await _setCurrentAccount(null);
    if (loggedOut && account != null) {
      SyncController.forAccount(account).dispose();
    }
    await Get.offAll(() => LoginScreen());
    return true;
  }

  Future<AuthResponse> login(String username, String password, {AppEnvironment? appEnv}) async {
    appEnv ??= AppEnvironment.Production;
    if (username.contains(ENV_DELIMITER)) {
      final chunks = username.split(ENV_DELIMITER);
      if (chunks.length == 2) {
        appEnv = AppEnvironment.byKey(chunks[0]) ?? appEnv;
        username = chunks[1];
      }
    }
    final u = UserAccount(email: username, password: password, id: -1, displayName: "", envName: appEnv.key);
    final resp = await (await (ApiRequestBuilder(HttpMethod.GET, "crud/users/me")..forAccount(u)).request()).send();
    if (resp.statusCode == 200) {
      final rawJson = await resp.stream.bytesToString();
      final Map<String, dynamic> result = jsonDecode(rawJson);
      final account = UserAccount(
          id: result["id"],
          email: u.email,
          password: u.password,
          displayName: "${result["user_first_name"]} ${result["user_last_name"]}",
          envName: appEnv.key);
      await _setCurrentAccount(account);
      return AuthResponse(success: true, account: account);
    } else if (resp.statusCode == 401) {
      return AuthResponse(success: false, message: 'Invalid login or password');
    } else {
      return AuthResponse(success: false, message: 'This request could not be completed');
    }
  }

  Future<bool> _setCurrentAccount(UserAccount? account, {bool persistAccount = true}) async {
    if (_currentAccount != account) {
      _currentAccount = account;
      if (persistAccount) {
        final prefs = await SharedPreferences.getInstance();

        if (account != null) {
          await prefs.setString(ACCOUNT_PREFS_KEY, jsonEncode(account.toJson()));
        } else {
          await prefs.remove(ACCOUNT_PREFS_KEY);
        }
      }
      return true;
    }
    return false;
  }
}
