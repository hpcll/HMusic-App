import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart' as hashes;
import 'package:pointycastle/export.dart';

/// 沿用 LX 的 AES/RSA 协议参数，算法由现有成熟加密库完成。
class LxCryptoBridge {
  Map<String, Object?> call(String operation, List<Object?> args) {
    try {
      return {
        'value': switch (operation) {
          'decode' => _decode(args[0], args[1] as String),
          'encode' => _encode(_bytes(args[0]), args[1] as String),
          'md5' => hashes.md5.convert(_bytes(args[0])).toString(),
          'random' => _random((args[0] as num).toInt()),
          'aes' => _aes(args),
          'rsa' => _rsa(_bytes(args[0]), args[1] as String),
          _ => throw const FormatException(),
        },
      };
    } catch (_) {
      return {'error': 'LX 加密参数无效'};
    }
  }

  List<int> _decode(Object? value, String encoding) {
    if (value is List<Object?>) return _bytes(value);
    final text = value as String;
    return switch (encoding.toLowerCase()) {
      'base64' => base64Decode(text),
      'binary' || 'latin1' => latin1.encode(text),
      'hex' => [
        for (var i = 0; i < text.length; i += 2)
          int.parse(text.substring(i, i + 2), radix: 16),
      ],
      _ => utf8.encode(text),
    };
  }

  String _encode(List<int> bytes, String encoding) =>
      switch (encoding.toLowerCase()) {
        'base64' => base64Encode(bytes),
        'binary' || 'latin1' => latin1.decode(bytes),
        'hex' =>
          bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join(),
        _ => utf8.decode(bytes),
      };

  Uint8List _bytes(Object? value) => Uint8List.fromList(
    value is String ? utf8.encode(value) : (value as List<Object?>).cast<int>(),
  );

  List<int> _random(int length) {
    if (length < 0 || length > 65536) throw const FormatException();
    final random = Random.secure();
    return List.generate(length, (_) => random.nextInt(256));
  }

  Uint8List _aes(List<Object?> args) {
    final data = _bytes(args[0]), key = _bytes(args[2]);
    if (key.length != 16) throw const FormatException();
    if (args[1] == 'aes-128-cbc') {
      final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
        ..init(
          true,
          PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
            ParametersWithIV(KeyParameter(key), _bytes(args[3])),
            null,
          ),
        );
      return cipher.process(data);
    }
    if (args[1] != 'aes-128-ecb' || data.length % 16 != 0) {
      throw const FormatException();
    }
    final cipher = ECBBlockCipher(AESEngine())..init(true, KeyParameter(key));
    final result = Uint8List(data.length);
    for (var offset = 0; offset < data.length; offset += 16) {
      cipher.processBlock(data, offset, result, offset);
    }
    return result;
  }

  Uint8List _rsa(Uint8List data, String pem) {
    final encoded = pem.replaceAll(RegExp(r'-----[^-]+-----|\s'), '');
    var sequence =
        ASN1Parser(base64Decode(encoded)).nextObject() as ASN1Sequence;
    if (sequence.elements.first is ASN1Sequence) {
      final bits = sequence.elements[1] as ASN1BitString;
      sequence =
          ASN1Parser(Uint8List.fromList(bits.stringValue)).nextObject()
              as ASN1Sequence;
    }
    final key = RSAPublicKey(
      (sequence.elements[0] as ASN1Integer).valueAsBigInteger,
      (sequence.elements[1] as ASN1Integer).valueAsBigInteger,
    );
    return (RSAEngine()..init(true, PublicKeyParameter<RSAPublicKey>(key)))
        .process(data);
  }
}
