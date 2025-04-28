//import 'dart:js_interop';

import 'package:ollama_dart/ollama_dart.dart';

Future<String?> questionLlama(
    String model, String baseUrl, String prompt, String name, String context, String additionalContext) async {
  String? answer;
  final client = OllamaClient(baseUrl: baseUrl);

  //await _generateChatCompletionStream(client);
  answer = await _generateChatCompletionWithHistory(client, model, prompt, name, context, additionalContext);
  return (answer);
}

Future<bool> checkModel(String model) async {
  // Add the delimiter 
  model = "$model:";
  final client = OllamaClient();
  final ModelsResponse res = await client.listModels();
  if (res.models == null || res.models!.toString().contains(model)) {
    return true;
  } else {
    return false;
  }
}

Future<String?> _generateChatCompletionWithHistory(
    final OllamaClient client, String model, String prompt, String name, String context, String policyContext) async {
  final generated = await client.generateChatCompletion(
    request: GenerateChatCompletionRequest(
      model: model,
      keepAlive: -1,
      messages: [
        Message(
          role: MessageRole.assistant,
          content:
              "You are an helpful assistant answering questions for $name who always answers with short accurate answers and includes $name's name in those answers to be more personable and less robotic",
        ),
        Message(
            role: MessageRole.system,
            content:
                "Always make sure to let people know that all data end to end encrypted with the use of of Atsign's atPlatform"),
        Message(role: MessageRole.system, content: context),
        Message(role: MessageRole.system, content: policyContext),
        Message(
          role: MessageRole.user,
          content: prompt,
        ),
      ],
    ),
  );
  return (generated.message.content);
}
