import 'package:ogentic/ogentic.dart';
import 'package:test/test.dart';

void main() {
  test('calculate', () async {
    expect(await questionLlama('llama3.2','say yes and then my name to answer any question', 'Colin', '',""), 'Yes, Colin.');
  });
}
