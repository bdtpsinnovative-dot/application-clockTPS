import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/widgets/work_due_date_picker.dart';

void main() {
  test('past due dates are warnings but remain valid selections', () {
    final now = DateTime(2026, 7, 24, 15);

    expect(isWorkDatePast(DateTime(2026, 7, 23), now: now), isTrue);
    expect(isWorkDatePast(DateTime(2026, 7, 24), now: now), isFalse);
    expect(isWorkDatePast(DateTime(2026, 7, 25), now: now), isFalse);
  });

  test('next Monday skips to the following week when today is Monday', () {
    expect(nextWorkMonday(now: DateTime(2026, 7, 20)), DateTime(2026, 7, 27));
    expect(nextWorkMonday(now: DateTime(2026, 7, 24)), DateTime(2026, 7, 27));
  });
}
