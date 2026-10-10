import 'package:flutter_test/flutter_test.dart';
import 'package:blue_mesh/utils/validators.dart';
import 'package:blue_mesh/utils/time_ago.dart';
import 'package:blue_mesh/core/result.dart';
import 'package:blue_mesh/core/platform_capabilities.dart';

void main() {
  group('Utils & Core Tests', () {
    test('InputValidators validateDisplayName', () {
      expect(InputValidators.validateDisplayName(null), isNotNull);
      expect(InputValidators.validateDisplayName(''), isNotNull);
      expect(InputValidators.validateDisplayName(' '), isNotNull);
      expect(InputValidators.validateDisplayName('A'), isNotNull);
      expect(InputValidators.validateDisplayName('ThisNameIsWayTooLongAndExceedsTwentyFourChars'), isNotNull);
      expect(InputValidators.validateDisplayName('Bob'), isNull);
    });

    test('InputValidators validateMessageText', () {
      expect(InputValidators.validateMessageText(null), isNotNull);
      expect(InputValidators.validateMessageText(''), isNotNull);
      expect(InputValidators.validateMessageText('   '), isNotNull);
      expect(InputValidators.validateMessageText('Hello!'), isNull);
      
      final longText = 'A' * 2000;
      expect(InputValidators.validateMessageText(longText), isNotNull);
    });

    test('TimeAgo format formats accurately', () {
      final now = DateTime.now();
      expect(TimeAgo.format(now.subtract(const Duration(seconds: 10))), 'just now');
      expect(TimeAgo.format(now.subtract(const Duration(minutes: 5))), '5m ago');
      expect(TimeAgo.format(now.subtract(const Duration(hours: 2))), '2h ago');
      expect(TimeAgo.format(now.subtract(const Duration(days: 1))), '1d ago');
      expect(TimeAgo.format(now.subtract(const Duration(days: 10))), isNotEmpty);
      expect(TimeAgo.formatTimeOnly(DateTime(2026, 1, 1, 14, 5)), '14:05');
    });

    test('Result success and failure behaviors', () {
      final success = Result<int, String>.success(42);
      expect(success.isSuccess, true);
      expect(success.isFailure, false);
      expect(success.valueOrNull, 42);
      expect(success.errorOrNull, isNull);

      final transformed = success.map((v) => v * 2);
      expect(transformed.valueOrNull, 84);

      final foldedSuccess = success.fold(
        onSuccess: (v) => 'Success: $v',
        onFailure: (e) => 'Error: $e',
      );
      expect(foldedSuccess, 'Success: 42');

      final failure = Result<int, String>.failure('Something went wrong');
      expect(failure.isSuccess, false);
      expect(failure.isFailure, true);
      expect(failure.valueOrNull, isNull);
      expect(failure.errorOrNull, 'Something went wrong');

      final foldedFailure = failure.fold(
        onSuccess: (v) => 'Success: $v',
        onFailure: (e) => 'Error: $e',
      );
      expect(foldedFailure, 'Error: Something went wrong');
    });

    test('PlatformCapabilities evaluates central and mode description', () async {
      expect(PlatformCapabilities.isCentralSupported, true);
      final desc = await PlatformCapabilities.getModeDescription();
      expect(desc.isNotEmpty, true);
    });
  });
}
