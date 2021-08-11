import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/uuid_util.dart';

T? readPrimitive<T>(dynamic v) {
  if (v is T) {
    return v;
  }
  if (T == DateTime) {
    var raw = readPrimitive<String>(v);
    if (raw != null) {
      return DateTime.tryParse(raw) as T?;
    }
  }
  if (T == int) {
    var raw = readPrimitive<String>(v);
    if (raw != null) {
      return int.tryParse(raw) as T?;
    }
  }
  if (T == double) {
    var raw = readPrimitive<String>(v);
    if (raw != null) {
      return double.tryParse(raw) as T?;
    }
  }

  if (T == bool) {
    var intBool = readPrimitive<int>(v);
    if (intBool != null) {
      return (intBool == 1) as T;
    }
    var raw = readPrimitive<String>(v);
    if (raw != null) {
      return (raw == '1') as T;
    }
  }

  return null;
}

final _uuid = Uuid(options: {'grng': UuidUtil.cryptoRNG});

String uuidGenV4() {
  return _uuid.v4();
}

extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (T element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

Color generateRandomColor() {
  return Color((Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0);
}

Widget emptyWidget() {
  return SizedBox.shrink();
}

Widget verticalFabSpacer() {
  return SizedBox(height: 66);
}

typedef Action1<T> = void Function(T arg);


class Pair<T, Q> {
  Pair(this.left, this.right);

  final T left;
  final Q right;

  @override
  String toString() => 'Pair[$left, $right]';
}


String md5Digest(String input){
  return md5.convert(utf8.encode(input)).toString();
}