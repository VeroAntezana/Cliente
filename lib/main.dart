import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'dialogflow_service.dart';
import 'gemini_service.dart';
import 'config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'database/firestore_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(VoiceApp());
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    print("✅ Firebase inicializado correctamente");
  } catch (e) {
    print("❌ Error al inicializar Firebase: $e");
  }
}

class VoiceApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: VoiceHomePage(),
    );
  }
}

class VoiceHomePage extends StatefulWidget {
  @override
  _VoiceHomePageState createState() => _VoiceHomePageState();
}

class _VoiceHomePageState extends State<VoiceHomePage> {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  late GeminiService geminiService;
  FirestoreService? firestoreService;
  bool isFirebaseReady = false;

  bool _isListening = false;
  String _text = "Presiona el botón y habla";
  String _response = "";
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    geminiService = GeminiService(apiKey: Config.GEMINI_API_KEY);

    // Inicializamos Firestore cuando Firebase esté listo
    _initFirestore();

    _flutterTts.setStartHandler(() {
      setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _initFirestore() async {
    try {
      setState(() {
        firestoreService = FirestoreService();
        isFirebaseReady = true;
      });

      // Obtener clientes
      if (firestoreService != null) {
        final clientes = await firestoreService?.getClientes();
        print("🔥 Clientes recibidos en main.dart: $clientes");
      }
    } catch (e) {
      print("❌ Error al inicializar Firestore: $e");
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => print("Estado del micrófono: $status"),
        onError: (error) => print("Error de micrófono: $error"),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() {
            _text = result.recognizedWords;
            if (result.finalResult) {
              _processCommand(_text);
            }
          });
        });
      } else {
        print("El reconocimiento de voz no está disponible.");
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _processCommand(String command) async {
    print("Comando recibido: $command");

    try {
      DialogflowService dialogflowService = DialogflowService();
      var dialogflowResult =
          await dialogflowService.sendMessageToDialogflow(command);

      String intent = dialogflowResult['intent'];
      Map<String, dynamic> parameters = dialogflowResult['parameters'];
      String dialogflowResponse = dialogflowResult['fulfillmentText'];

      print("Intent detectado: $intent");
      print("Parámetros: $parameters");
      print("Respuesta de Dialogflow: $dialogflowResponse");

      // Si es un saludo o intent general, solo usa la respuesta de Dialogflow
      final soloDialogflow = [
        'Default Welcome Intent',
        'Default Fallback Intent',
        // Agrega aquí otros intents de saludos o conversación general
      ];

// Si es un saludo o intent general, solo usa la respuesta de Dialogflow
      if (soloDialogflow.contains(intent)) {
        setState(() {
          _response = dialogflowResponse;
        });
        _speak(dialogflowResponse);
        return; // Termina aquí si es un saludo
      }

      String response;

      // Solo intentamos obtener datos de Firebase si está listo
      if (isFirebaseReady && firestoreService != null) {
        List<Map<String, dynamic>> clientes =
            await firestoreService!.getClientes();

        if (clientes.isNotEmpty) {
          String geminiMessage;

          switch (intent) {
            case 'consulta_deuda':
              if (parameters.containsKey('person')) {
                // Consulta específica de deuda por nombre
                String nombre = parameters['person'];
                geminiMessage = """
              Tengo estos datos de clientes:
              ${clientes.map((c) => "Nombre: ${c['nombre']}, Deuda: ${c['saldoDeuda']}").join("\n")}
              
              ¿Cuál es la deuda del cliente llamado '$nombre'?
              Si encuentras al cliente, responde solo con su deuda.
              Si no lo encuentras, indica que no existe el cliente.
              """;
              } else {
                // Consulta general de deudas
                geminiMessage = """
              Tengo estos datos de clientes:
              ${clientes.map((c) => "Nombre: ${c['nombre']}, Deuda: ${c['saldoDeuda']}").join("\n")}
              
              ${parameters.containsKey('deuda') ? "¿Quién tiene la mayor deuda?" : "Resume todas las deudas."}
              """;
              }
              break;

            case 'consulta_compras':
              geminiMessage = """
            Datos de compras de clientes:
            ${clientes.map((c) => "Nombre: ${c['nombre']}, Total Compras: ${c['totalCompras']}, Promedio: ${c['montoPromedio']}").join("\n")}
            
            ${parameters.containsKey('compras') ? "¿Quién ha realizado más compras?" : "Resume las compras de todos los clientes."}
            """;
              break;

            case 'consulta_tiempo':
              geminiMessage = """
            Historial de clientes:
            ${clientes.map((c) => "Nombre: ${c['nombre']}, Ingreso: ${c['fechaIngreso']}, Egreso: ${c['fechaEgreso']}").join("\n")}
            
            ${parameters.containsKey('tiempo') ? "¿Quién es el cliente más antiguo?" : "Lista los clientes por antigüedad."}
            """;
              break;

            default:
              // Consulta general o no reconocida
              geminiMessage = """
            Información completa de clientes:
            ${clientes.map((c) => """
              Nombre: ${c['nombre']}
              Deuda: ${c['saldoDeuda']}
              Compras totales: ${c['totalCompras']}
              Fecha ingreso: ${c['fechaIngreso']}
            """).join("\n")}
            
            Responde a esta consulta: '$command'
            Da una respuesta clara y concisa.
            """;
          }

          String geminiResponse =
              await geminiService.sendMessageToGemini(geminiMessage);
          response = "$dialogflowResponse $geminiResponse";
        } else {
          response = "No encontré datos relevantes en la base de clientes.";
        }
      } else {
        response =
            "La base de datos aún no está lista. Por favor, intenta de nuevo en unos segundos.";
      }

      setState(() {
        _response = response;
      });

      _speak(response);
    } catch (e) {
      print("Error en processCommand: $e");
      setState(() {
        _response = "Ocurrió un error al procesar tu solicitud.";
      });
      _speak("Ocurrió un error al procesar tu solicitud.");
    }
  }

  void _speak(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
    }
    setState(() => _isSpeaking = true);
    await _flutterTts.speak(text);
  }

  void _stopSpeaking() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Voice Command App-Cliente')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Text(
                  _response,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 80),
              ],
            ),
          ),
          if (_isSpeaking)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: _stopSpeaking,
                icon: Icon(Icons.stop),
                label: Text('Detener'),
                backgroundColor: Colors.red,
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _listen,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
    );
  }
}
