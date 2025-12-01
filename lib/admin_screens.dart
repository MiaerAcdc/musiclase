import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';

/// ROOT DEL ADMIN
class AdminRoot extends StatelessWidget {
  const AdminRoot({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin — MusiClase"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: const AdminVerificacionProfesores(),
    );
  }
}

/// PANTALLA: Verificación de profesores (HU-E3 / RF5)
class AdminVerificacionProfesores extends StatelessWidget {
  const AdminVerificacionProfesores({super.key});

  Future<void> _aprobarProfesor(BuildContext context, String id) async {
    await FirebaseFirestore.instance
        .collection("profesores")
        .doc(id)
        .update({"verificado": true});

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profesor verificado.")),
    );
  }

  Future<void> _rechazarProfesor(BuildContext context, String id) async {
    await FirebaseFirestore.instance
        .collection("profesores")
        .doc(id)
        .delete();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profesor rechazado/eliminado.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("profesores")
          .where("verificado", isEqualTo: false)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "No hay profesores pendientes de verificación.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              "Verificación de profesores",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...docs.map((d) {
              final p = d.data() as Map<String, dynamic>;
              final nombre = p["nombre"] ?? "Sin nombre";
              final instrumento = p["instrumento"] ?? "Instrumento";
              final modalidad = p["modalidad"] ?? "Modalidad";

              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(nombre[0])),
                  title: Text(nombre),
                  subtitle: Text("$instrumento • $modalidad\nDocs: (mock) CV, certificados"),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () => _rechazarProfesor(context, d.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _aprobarProfesor(context, d.id),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
