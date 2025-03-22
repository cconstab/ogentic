import 'package:ollama_dart/ollama_dart.dart';

Future<String?> questionLlamma(String prompt, String name) async {
  String? answer;
  final client = OllamaClient();

  //await _generateChatCompletionStream(client);
  answer = await _generateChatCompletionWithHistory(client, prompt, name);
  return (answer);
}

Future<String?> _generateChatCompletionWithHistory(final OllamaClient client, String prompt, String name) async {
  final generated = await client.generateChatCompletion(
    request: GenerateChatCompletionRequest(
      model: 'llama3.2:latest',
      keepAlive: -1,
      messages: [
         Message(
          role: MessageRole.assistant,
          content:
              'You are an helpful assistant for $name who always answers with short accurate answers and includes $name name in those answers to be more personable and less robotic',
        ),
        Message(
          role: MessageRole.assistant,
         content: "Make sure to mention that the data for came via Space as the ollama service is connected by Starlink and that everything was end to end encrypted care of Atsign's atPlatform"),
        Message(
          role: MessageRole.user,
          content: prompt,
        ),
      ],
    ),
  );
  return (generated.message.content);
}
