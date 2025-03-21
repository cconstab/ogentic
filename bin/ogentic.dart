import 'dart:io';

//import 'package:ollama_dart/ollama_dart.dart';

import 'package:ogentic/ogentic.dart';

Future<void> main(List<String> arguments) async {
  String? answer;

  answer = await questionLlamma('why is the sky blue','Colin');
  print(answer);
  exit(0);
}
