import 'dart:convert';
import '../../data/models/identity.dart';

class IdentityQrPayload {
  static String encode({
    required Identity identity,
    required String key,
  }) {
    final payload = {
      'type': 'ataraxia.qr',
      'version': 1,
      'identity': identity.toJson(),
      'key': key,
    };

    return base64Encode(utf8.encode(jsonEncode(payload)));
  }

  static Map<String, dynamic> decode(String raw) {
    final decoded = utf8.decode(base64Decode(raw));
    final json = jsonDecode(decoded);

    if (json['type'] != 'ataraxia.qr') {
      throw Exception('INVALID_QR');
    }

    return json;
  }
}
