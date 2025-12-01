import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import 'alumno_screens.dart';
import 'profesor_screens.dart';
import 'admin_screens.dart';
import 'gestor_screens.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nombreCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  String rol = "alumno";

  bool loading = false;

  Future<void> registrar() async {
    if (nombreCtrl.text.trim().isEmpty ||
        emailCtrl.text.trim().isEmpty ||
        passCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Todos los campos son obligatorios")),
      );
      return;
    }

    try {
      setState(() => loading = true);

      // 1. Crear usuario en Auth
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      // 2. Crear documento en Firestore
      await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(uid)
          .set({
        "nombre": nombreCtrl.text.trim(),
        "email": emailCtrl.text.trim(),
        "rol": rol,
        "creado": DateTime.now(),
      });

      if (!mounted) return;

      // 3. Redirección según rol
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crear cuenta")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                label: Text("Nombre completo"),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                label: Text("Correo"),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                label: Text("Contraseña"),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 20),

            // Selección de rol
            DropdownButtonFormField(
              value: rol,
              decoration: const InputDecoration(
                labelText: "Rol en MusiClase",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "alumno", child: Text("Alumno")),
                DropdownMenuItem(value: "profesor", child: Text("Profesor")),
                DropdownMenuItem(value: "admin", child: Text("Administrador")),
                DropdownMenuItem(value: "gestor", child: Text("Gestor")),
              ],
              onChanged: (v) => setState(() => rol = v!),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: loading ? null : registrar,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Crear cuenta"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
