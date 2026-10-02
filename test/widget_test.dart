import 'package:flutter_test/flutter_test.dart';
import 'package:akmusic_flutter/core/config/app_constants.dart';
import 'package:akmusic_flutter/core/theme/app_theme.dart';

void main() {
  test('AK Music Core Configuration & Theme test', () {
    expect(AppConstants.appName, 'AK Music');
    expect(AppTheme.primaryColor, isNotNull);
  });
}
