import 'package:ollama_dart/ollama_dart.dart';

Future<String?> questionLlama(
    String prompt, String name, String context, String additionalContext) async {
  String? answer;
  final client = OllamaClient();

  //await _generateChatCompletionStream(client);
  answer =
      await _generateChatCompletionWithHistory(client, prompt, name, context, additionalContext);
  return (answer);
}

Future<String?> _generateChatCompletionWithHistory(final OllamaClient client,
    String prompt, String name, String context, String policyContext) async {
  final generated = await client.generateChatCompletion(
    request: GenerateChatCompletionRequest(
      model: 'llama3.2:latest',
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
        Message(
          role: MessageRole.user,
          content: prompt,
        ),
        Message(role: MessageRole.system, content: policyContext),
      ],
    ),
  );
  return (generated.message.content);
}
