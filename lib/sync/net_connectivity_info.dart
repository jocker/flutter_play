
import 'package:connectivity_plus/connectivity_plus.dart';

typedef NetConnectivityInfoChangedCallback = Function(int value);

class NetConnectivityInfo {
  static const _CONN_NONE = 0,
      _CONN_WIFI = 1 << 1,
      _CONN_MOBILE = 1 << 2,
      _CONN_MASK = _CONN_NONE | _CONN_WIFI | _CONN_MOBILE;
  static const _MODE_ONLINE = 0, _MODE_OFFLINE = 1 << 3, _MODE_MASK = _MODE_ONLINE | _MODE_OFFLINE;
  static const _API_REACHABLE = 0, _API_UNREACHABLE = 1 << 4, _API_MASK = _API_REACHABLE | _API_UNREACHABLE;

  NetConnectivityInfo(this._value);

  int _value;
  NetConnectivityInfoChangedCallback? _changedCallback;

  bool setConnectivityResult(ConnectivityResult res) {
    int newFlag = _CONN_NONE;
    switch (res) {
      case ConnectivityResult.wifi:
        newFlag = _CONN_WIFI;
        break;
      case ConnectivityResult.mobile:
        newFlag = _CONN_MOBILE;
        break;
      case ConnectivityResult.none:
        newFlag = _CONN_NONE;
        break;
      default:
        return false;
    }

    return _setFlag(_CONN_MASK, newFlag);
  }

  bool setOfflineModeEnabled(bool offlineEnabled) {
    return _setFlag(_MODE_MASK, offlineEnabled ? _MODE_OFFLINE : _MODE_ONLINE);
  }

  bool setApiReachable(bool apiReachable) {
    return _setFlag(_API_MASK, apiReachable ? _API_REACHABLE : _API_UNREACHABLE);
  }

  bool get connected {
    return _value & _CONN_MASK != _CONN_NONE;
  }

  bool get apiReachable {
    return _value & _API_MASK == _API_REACHABLE;
  }

  bool get offlineModeEnabled {
    return _value & _MODE_MASK == _MODE_OFFLINE;
  }

  bool get networkingEnabled {
    return connected && apiReachable && !offlineModeEnabled;
  }

  int get value {
    return _value;
  }

  bool _setFlag(int remove, int add) {
    final newValue = _value ^ remove | add;
    if (newValue != _value) {
      _value = newValue;
      _notifyChanged();
      return true;
    }
    return false;
  }

  setValue(int newValue) {
    newValue = newValue & (_CONN_MASK | _MODE_MASK | _API_MASK);
    if (newValue != _value) {
      _value = newValue;
      _notifyChanged();
    }
  }

  _notifyChanged() {
    final callback = _changedCallback;
    if (callback != null) {
      callback(_value);
    }
  }

  onChanged(NetConnectivityInfoChangedCallback fn) {
    _changedCallback = fn;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is NetConnectivityInfo && runtimeType == other.runtimeType && _value == other._value;

  @override
  int get hashCode => _value.hashCode;
}
