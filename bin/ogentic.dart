import 'dart:io';

import 'package:ollama_dart/ollama_dart.dart';

Future<void> main(List<String> arguments) async {
  String? answer;
  final client = OllamaClient();

  //await _generateChatCompletionStream(client);
  answer = await _generateChatCompletionWithHistory(client, "why is the sky blue ?");
  print(answer);
  exit(0);
}

Future<String?> _generateChatCompletionWithHistory(
  final OllamaClient client, String prompt
) async {
  final generated = await client.generateChatCompletion(
    request: const GenerateChatCompletionRequest(
      model: 'qwen2.5:32b-instruct-q4_K_M',
      messages: [
        Message(
          role: MessageRole.user,
          content: 'You are an helpful assistant answering questions from Colin and always mentions Colin in the reply',
        ),
        Message(
          role: MessageRole.assistant,
          content: "why is the sky blue?",
        ),
      ],
    ),
  );
  return(generated.message.content);
}