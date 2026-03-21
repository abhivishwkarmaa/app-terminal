import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  final _secureStorage = const FlutterSecureStorage();
  final _algorithm = AesGcm.with256bits();
  
  static const String _masterKeyName = 'e2ee_master_key';

  Future<SecretKey> _getOrGenerateMasterKey() async {
    String? keyBase64 = await _secureStorage.read(key: _masterKeyName);
    if (keyBase64 == null) {
      final newKey = _algorithm.newSecretKey();
      final keyBytes = await (await newKey).extractBytes();
      await _secureStorage.write(key: _masterKeyName, value: base64Encode(keyBytes));
      return newKey;
    }
    return SecretKey(base64Decode(keyBase64));
  }

  Future<String> encrypt(String plaintext) async {
    if (plaintext.isEmpty) return '';
    final secretKey = await _getOrGenerateMasterKey();
    
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
    );
    
    // Concatenate nonce + mac + ciphertext for an all-in-one blob
    final combined = [
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ];
    
    return base64Encode(combined);
  }

  Future<String> decrypt(String encryptedBlob) async {
    if (encryptedBlob.isEmpty) return '';
    final secretKey = await _getOrGenerateMasterKey();
    final combined = base64Decode(encryptedBlob);
    
    // Nonce is 12 bytes for AES-GCM in this package by default
    // MAC is 16 bytes
    const nonceLength = 12;
    const macLength = 16;
    
    if (combined.length < nonceLength + macLength) {
      throw Exception('Invalid encrypted blob');
    }
    
    final nonce = combined.sublist(0, nonceLength);
    final macBytes = combined.sublist(nonceLength, nonceLength + macLength);
    final ciphertext = combined.sublist(nonceLength + macLength);
    
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    
    final decryptedBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    
    return utf8.decode(decryptedBytes);
  }
}
