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
         content: "Always mention that all the data to the ollama service  was end to end encrypted care of Atsign's atPlatform and that the packets went via Space as the server is connected by Starlink"),
        Message(
          role: MessageRole.user,
          content: prompt,
        ),
      ],
    ),
  );
  return (generated.message.content);
}
