import 'package:ogentic/ogentic.dart';
import 'package:test/test.dart';

void main() {
  test('calculate', () async {
    expect(await questionLlamma('say yes','Colin'), 'Yes, Colin.');
  });
}
