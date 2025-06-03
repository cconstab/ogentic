
import 'package:ollama_dart/ollama_dart.dart';

Future<String?> questionLlama(OllamaClient client, String model, String prompt,
    String name, String context, String additionalContext, String role) async {
  String? answer;
  //await _generateChatCompletionStream(client);
  answer = await _generateChatCompletionWithHistory(
      client, model, prompt, name, context, additionalContext, role);
  return (answer);
}

Future<bool> checkModel(OllamaClient client, String model) async {
  // Add the delimiter
  final ModelsResponse res = await client.listModels();
  if (res.models == null || res.models!.toString().contains('$model:')) {
    // load model with a good question
     _generateChatCompletionWithHistory(client, model,
        'what is the meaning of life', '', '', "","");
    return true;
  } else {
    return false;
  }
}

Future<String?> _generateChatCompletionWithHistory(
    final OllamaClient client,
    String model,
    String prompt,
    String name,
    String context,
    String policyContext,
    String role) async {
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
                role),
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
