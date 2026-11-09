import 'package:flutter_test/flutter_test.dart';
import 'package:mindora_family/services/notification_service.dart';

void main() {
  test('NotificationService singleton olarak oluşturuluyor', () {
    final first = NotificationService.instance;
    final second = NotificationService.instance;

    expect(identical(first, second), isTrue);
  });
}
