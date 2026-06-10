import 'dart:convert';

class EncryptionUtil {
  static const String _key = 'chat';

  static bool hasEmoji(String str) {
    // Regex matching common emoji ranges
    final RegExp emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1FA70}-\u{1FAFF}\u{1F1E6}-\u{1F1FF}\u{200D}\u{FE0F}]+',
      unicode: true,
    );
    return emojiRegex.hasMatch(str);
  }

  static String encrypt(String content) {
    if (hasEmoji(content)) {
      return content;
    }

    if (!content.startsWith('data:')) {
      try {
        String result = '';
        for (int i = 0; i < content.length; i++) {
          int charCode = content.codeUnitAt(i);
          int keyChar = _key.codeUnitAt(i % _key.length);
          result += String.fromCharCode(charCode ^ keyChar);
        }

        List<int> bytes = result.codeUnits;
        String base64Str = base64Encode(bytes);
        return 'data:$base64Str';
      } catch (e) {
        // Fallback for characters that can't be base64 encoded (e.g. > 255 code unit)
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
        String raw = String.fromCharCodes(decodedBytes);

        String out = '';
        for (int i = 0; i < raw.length; i++) {
          int charCode = raw.codeUnitAt(i);
          int keyChar = _key.codeUnitAt(i % _key.length);
          out += String.fromCharCode(charCode ^ keyChar);
        }
        return out;
      } catch (e) {
        return encrypted;
      }
    }
    return encrypted;
  }
}
