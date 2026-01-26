import 'dart:async';
import 'package:flutter/foundation.dart'; // Для debugPrint
import 'package:http/http.dart' as http;

class AppConfig {
  // Хардкод IP убран, оставлен только продакшн URL
  static String get baseUrl {
    return 'https://chords-pro.onrender.com';
  }

  /// Выполняет GET запрос с автоматическими повторными попытками
  /// 1-я попытка: сразу
  /// 2-я попытка: через 1 секунду
  /// 3-я попытка: через 2 секунды
  /// Если все попытки провалены, пробрасывает исключение
  static Future<http.Response> getWithRetry(
    String url, {
    int maxAttempts = 3,
  }) async {
    final List<int> delaySeconds = [0, 1, 2];

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Ожидаем перед попыткой (для 2-й и 3-й попыток)
        if (attempt > 1) {
          await Future.delayed(Duration(seconds: delaySeconds[attempt - 1]));
        }

        final Uri uri = Uri.parse(url);
        final response = await http
            .get(uri)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () =>
                  throw TimeoutException('Timeout при получении $url'),
            );

        // Если статус 200 - успех
        if (response.statusCode == 200) {
          return response;
        }

        // Если статус не 200, выводим ошибку и продолжаем попытки
        debugPrint(
          'getWithRetry попытка $attempt/$maxAttempts: статус ${response.statusCode} для $url',
        );
      } catch (e) {
        // Выводим ошибку при исключении
        debugPrint(
          'getWithRetry попытка $attempt/$maxAttempts: исключение для $url - $e',
        );

        // Если это последняя попытка, пробрасываем исключение
        if (attempt == maxAttempts) {
          rethrow;
        }
      }
    }

    // Этот код не должен быть достигнут, но на случай
    throw Exception(
      'getWithRetry: все $maxAttempts попытки провалены для $url',
    );
  }
}
