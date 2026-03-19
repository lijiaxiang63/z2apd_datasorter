import 'package:flutter_test/flutter_test.dart';
import 'package:z2apd_datasorter/widgets/scan_series_dialog.dart';

void main() {
  group('bulkSelectionState', () {
    test('returns false for empty selections', () {
      expect(bulkSelectionState(const []), isFalse);
    });

    test('returns false when nothing is selected', () {
      expect(bulkSelectionState(const [false, false, false]), isFalse);
    });

    test('returns true when everything is selected', () {
      expect(bulkSelectionState(const [true, true, true]), isTrue);
    });

    test('returns null when selection is mixed', () {
      expect(bulkSelectionState(const [true, false, true]), isNull);
    });
  });
}
