import 'package:flutter_test/flutter_test.dart';
import 'package:smart_parking_mobile/config/app_config.dart';

void main() {
  test('Family Link modu varsayılan olarak açıktır', () {
    expect(AppConfig.familyLinkMode, isTrue);
  });
}
