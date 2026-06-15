import 'dart:convert';

class EncryptionUtil {
  static const String _key = 'chat';

  static String encrypt(String content) {
    if (!content.startsWith('data:')) {
      try {
        final keyBytes = utf8.encode(_key);
        final contentBytes = utf8.encode(content);
        
        final List<int> resultBytes = [];
        for (int i = 0; i < contentBytes.length; i++) {
          resultBytes.add(contentBytes[i] ^ keyBytes[i % keyBytes.length]);
        }

        String base64Str = base64Encode(resultBytes);
        return 'data:$base64Str';
      } catch (e) {
        return content;
      }
    }
    return content;
  }

  static String decrypt(String encrypted) {
    if (encrypted.startsWith('data:')) {
      try {
        String base64Str = encrypted.substring(5);
        List<int> decodedBytes = base64Decode(base64Str);
        
        final keyBytes = utf8.encode(_key);
        final List<int> resultBytes = [];
        for (int i = 0; i < decodedBytes.length; i++) {
          resultBytes.add(decodedBytes[i] ^ keyBytes[i % keyBytes.length]);
        }
        
        return utf8.decode(resultBytes);
      } catch (e) {
        return encrypted;
      }
    }
    return encrypted;
  }
}
