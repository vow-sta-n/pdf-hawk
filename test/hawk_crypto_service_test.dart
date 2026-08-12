import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfhawk/logic/services/hawk_crypto_service.dart';

void main() {
  group('HawkCryptoService Tests', () {
    test('Encrypt and Decrypt JSON payload correctly', () {
      final sampleData = {
        "title": "Test Document",
        "elements": [
          {"id": "el_1", "type": "text", "content": "Hello World"}
        ]
      };
      final jsonStr = jsonEncode(sampleData);

      final encryptedBytes = HawkCryptoService.encryptJson(jsonStr);
      expect(encryptedBytes, isNotEmpty);

      final decryptedStr = HawkCryptoService.decryptHawkBytes(encryptedBytes);
      expect(decryptedStr, equals(jsonStr));

      final decoded = jsonDecode(decryptedStr) as Map<String, dynamic>;
      expect(decoded['title'], equals('Test Document'));
    });

    test('Throw FormatException on corrupt header or short byte array', () {
      expect(
        () => HawkCryptoService.decryptHawkBytes(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<FormatException>()),
      );

      final invalidBytes = Uint8List.fromList([
        ...utf8.encode("BADMAGIC"),
        1,
        2,
        3,
        4,
      ]);
      expect(
        () => HawkCryptoService.decryptHawkBytes(invalidBytes),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
