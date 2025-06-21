import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/identity.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class IdentityChecksum {
  static List<int> bytesFor(Identity identity) {
    final input = '${identity.id}:${identity.keyHash}';
    final hash = sha256.convert(utf8.encode(input)).bytes;
    return hash.take(12).toList(); // compact but unique
  }

  static Color colorFrom(int value) {
    final hue = (value % 360).toDouble();
    return HSVColor.fromAHSV(1, hue, 0.6, 0.9).toColor();
  }
}
