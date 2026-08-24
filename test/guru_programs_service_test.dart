import 'package:flutter_test/flutter_test.dart';
import 'package:halo/services/guru_programs_service.dart';

void main() {
  group('GuruProgramsService', () {
    test('GuruProgramType round-trip', () {
      expect(GuruProgramType.program.firestoreValue, 'program');
      expect(GuruProgramType.product.firestoreValue, 'product');
      expect(GuruProgramType.classBatch.firestoreValue, 'class');
      expect(GuruProgramTypeX.fromRaw('class'), GuruProgramType.classBatch);
    });

    test('GuruProgramsLoadResult filters by type', () {
      const result = GuruProgramsLoadResult(all: [
        {'id': '1', 'type': 'program', 'name': 'HIIT Plan'},
        {'id': '2', 'type': 'product', 'name': 'Protein'},
        {'id': '3', 'type': 'class', 'name': 'Morning Batch'},
      ]);

      expect(result.programs.length, 1);
      expect(result.products.length, 1);
      expect(result.classes.length, 1);
    });

    test('asClassView maps schedule fields', () {
      final view = GuruProgramsService.asClassView({
        'id': 'abc',
        'name': 'Yoga Batch',
        'schedule': 'Mon Wed Fri',
        'enrolled': 4,
        'capacity': 12,
        'price': 1500,
      });
      expect(view['name'], 'Yoga Batch');
      expect(view['schedule'], 'Mon Wed Fri');
      expect(view['capacity'], 12);
    });
  });
}
