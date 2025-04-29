import 'package:ogentic/ogentic.dart';
import 'package:ollama_dart/ollama_dart.dart';
import 'package:test/test.dart';

void main() {
  test('calculate', () async {
    final client = OllamaClient(baseUrl: 'http://localhost:11434/api');
    expect(await questionLlama(client ,'llama3.2','say yes and then my name to answer any question', 'Colin', '',""), 'Yes, Colin.');
  });
}
