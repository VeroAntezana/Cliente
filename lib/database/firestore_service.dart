import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getClientes() async {
    try {
      var snapshot = await _db.collection("clientes").get();

      if (snapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> clientes =
            snapshot.docs.map((doc) => doc.data()).toList();
        print(" Clientes obtenidos correctamente: $clientes");
        return clientes;
      } else {
        print("⚠ No hay clientes en la base de datos.");
        return [];
      }
    } catch (e) {
      print(" Error obteniendo clientes: $e");
      return [];
    }
  }
}
