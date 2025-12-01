import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'register_screen.dart';
import 'alumno_screens.dart';
import 'profesor_screens.dart';
import 'admin_screens.dart';
import 'gestor_screens.dart';
import 'seeder_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;

  Future<void> login() async {
    if (emailCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa los campos")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      // 1. Autenticación en Firebase
      final auth = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );

      // 2. Obtener UID
      final uid = auth.user!.uid;

      // 3. Obtener documento del usuario
      final doc = await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(uid)
          .get();

      if (!doc.exists) {
        throw "El usuario no tiene un rol asignado.";
      }

      final rol = doc["rol"];

      if (!mounted) return;

      // 4. Redirección según rol
      Widget destino;

      switch (rol) {
        case "alumno":
          destino = const AlumnoRoot();
          break;
        case "profesor":
          destino = const ProfesorRoot();
          break;
        case "admin":
          destino = const AdminRoot();
          break;
        case "gestor":
          destino = const GestorRoot();
          break;
        default:
          destino = const LoginScreen();
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destino),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            elevation: 7,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_note, size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    "MusiClase",
                    style: TextStyle(fontSize: 26),
                  ),

                  const SizedBox(height: 24),

                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: "Correo",
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Contraseña",
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : login,
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Ingresar"),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // BOTÓN DE REGISTRO
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text("Crear cuenta nueva"),
                  ),

                  //TextButton(
                  //  onPressed: () {
                  //   Navigator.push(
                  //      context,
                  //     MaterialPageRoute(builder: (_) => const SeederScreen()),
                  //    );
                  //  },
                  //  child: const Text("⚙ Cargar datos de prueba"),
                  //),


                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


