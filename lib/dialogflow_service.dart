import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

class DialogflowService {
  static const String _dialogflowUrl =
      "https://dialogflow.googleapis.com/v2/projects/[PROJECT_ID]/agent/sessions/[SESSION_ID]:detectIntent";

  // Función para enviar un mensaje a Dialogflow y recibir la respuesta
  Future<Map<String, dynamic>> sendMessageToDialogflow(String text) async {
    final serviceAccountCredentials = ServiceAccountCredentials.fromJson(
        json.decode(
            await rootBundle.loadString('assets/dialogflow_credentials.json')));

    final client = await clientViaServiceAccount(serviceAccountCredentials,
        ['https://www.googleapis.com/auth/cloud-platform']);

    final body = jsonEncode({
      "queryInput": {
        "text": {"text": text, "languageCode": "es"}
      }
    });

    final String url = _dialogflowUrl
        .replaceAll("[PROJECT_ID]", "alimento-mjll")
        .replaceAll("[SESSION_ID]", "12345");

    final response = await client.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    client.close();

    final responseData = jsonDecode(response.body);
    final queryResult = responseData['queryResult'];

    return {
      'intent': queryResult['intent']['displayName'] ?? '',
      'parameters': queryResult['parameters'] ?? {},
      'fulfillmentText': queryResult['fulfillmentText'] ?? '',
    };
  }
}
