import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'login_screen.dart';
import 'alumno_screens.dart';
import 'profesor_screens.dart';
import 'admin_screens.dart';
import 'gestor_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MusiClaseApp());
}

class MusiClaseApp extends StatelessWidget {
  const MusiClaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MusiClase",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const AuthGate(),
    );
  }
}

// ===============================
//  AUTHGATE → Ruteo por roles
// ===============================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snap.hasData) return const LoginScreen();

        final uid = snap.data!.uid;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection("usuarios").doc(uid).get(),
          builder: (_, userSnap) {
            if (!userSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (!userSnap.data!.exists) return const LoginScreen();

            final data = userSnap.data!.data() as Map<String, dynamic>;
            final rol = data["rol"] ?? "";

            switch (rol) {
              case "alumno":
                return const AlumnoRoot();
              case "profesor":
                return const ProfesorRoot();
              case "admin":
                return const AdminRoot();
              case "gestor":
                return const GestorRoot();
              default:
                return const LoginScreen();
            }
          },
        );
      },
    );
  }
}
