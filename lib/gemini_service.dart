import 'package:google_generative_ai/google_generative_ai.dart';
import 'config.dart';

class GeminiService {
  final String apiKey;
  late GenerativeModel model;

  GeminiService({required this.apiKey}) {
    print(
        "Inicializando GeminiService con API Key: ${apiKey.substring(0, 5)}...");
    if (apiKey.isEmpty) {
      throw Exception('API key no configurada correctamente');
    }

    try {
      print("Creando instancia de GenerativeModel...");
      model = GenerativeModel(
        model: 'gemini-pro',
        apiKey: apiKey,
      );
      print("GenerativeModel inicializado correctamente");
    } catch (e) {
      print("Error al inicializar el modelo de Gemini: $e");
    }
  }

  Future<String> sendMessageToGemini(String text) async {
    try {
      print("Enviando mensaje a Gemini: '$text'");

      final content = [Content.text(text)];
      final response = await model.generateContent(content);

      print("Respuesta recibida de Gemini: ${response.text}");
      return response.text ?? 'No se pudo generar una respuesta';
    } catch (e) {
      print("Error detallado en Gemini: $e");

      if (e.toString().contains('API key not valid')) {
        print(
            "⚠️ La API Key proporcionada no es válida. Verifica tu configuración.");
      }

      return ' Error al procesar el mensaje: $e';
    }
  }
}
