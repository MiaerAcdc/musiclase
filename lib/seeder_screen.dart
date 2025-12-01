import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SeederScreen extends StatefulWidget {
  const SeederScreen({super.key});

  @override
  State<SeederScreen> createState() => _SeederScreenState();
}

class _SeederScreenState extends State<SeederScreen> {
  bool loading = false;
  String mensaje = "";

  Future<void> cargarDatos() async {
    setState(() {
      loading = true;
      mensaje = "Cargando datos de prueba en Firebase...";
    });

    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    try {
      // =========================================
      // 1. CREAR USUARIOS EN AUTH (alumnos, profes, admin, gestor)
      // =========================================

      final List<Map<String, String>> usuariosDev = [
        {
          "email": "alumno1@musi.com",
          "password": "123456",
          "rol": "alumno",
          "nombre": "Luis Piano"
        },
        {
          "email": "alumno2@musi.com",
          "password": "123456",
          "rol": "alumno",
          "nombre": "Carla Canto"
        },
        {
          "email": "profesor.guitarra@musi.com",
          "password": "123456",
          "rol": "profesor",
          "nombre": "Ana Guitarra"
        },
        {
          "email": "profesor.canto@musi.com",
          "password": "123456",
          "rol": "profesor",
          "nombre": "Marcos Vocal Coach"
        },
        {
          "email": "admin@musi.com",
          "password": "123456",
          "rol": "admin",
          "nombre": "Admin MusiClase"
        },
        {
          "email": "gestor@musi.com",
          "password": "123456",
          "rol": "gestor",
          "nombre": "Gestor Finanzas"
        },
      ];

      // email -> uid
      final Map<String, String> emailToUid = {};

      for (final u in usuariosDev) {
        final email = u["email"]!;
        final password = u["password"]!;

        try {
          final cred = await auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          emailToUid[email] = cred.user!.uid;
        } catch (_) {
          // Si ya existe, lo logueamos para obtener el UID
          final cred = await auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          emailToUid[email] = cred.user!.uid;
        }
      }

      // =========================================
      // 2. COLECCIÓN "usuarios" CON ROLES
      // =========================================

      for (final u in usuariosDev) {
        final email = u["email"]!;
        final uid = emailToUid[email]!;
        await firestore.collection("usuarios").doc(uid).set({
          "nombre": u["nombre"],
          "email": email,
          "rol": u["rol"],
          "creado": DateTime.now(),
        }, SetOptions(merge: true));
      }

      // =========================================
      // 3. COLECCIÓN "profesores" (perfiles + tarifas + disponibilidad)
      // RF1, HU-C1, HU-E1
      // =========================================

      final profesorGuitarraUid = emailToUid["profesor.guitarra@musi.com"]!;
      final profesorCantoUid = emailToUid["profesor.canto@musi.com"]!;

      await firestore.collection("profesores").doc(profesorGuitarraUid).set({
        "nombre": "Ana Guitarra",
        "instrumento": "Guitarra",
        "modalidad": "Online",
        "tarifa": 80,
        "verificado": true, // aparecerá en búsqueda del alumno
        "diasDisponibles": {
          "Lun": true,
          "Mar": true,
          "Mie": false,
          "Jue": true,
          "Vie": true,
          "Sab": false,
          "Dom": false,
        },
        "horaInicio": "18:00",
        "horaFin": "21:00",
      });

      await firestore.collection("profesores").doc(profesorCantoUid).set({
        "nombre": "Marcos Vocal Coach",
        "instrumento": "Canto",
        "modalidad": "Presencial",
        "tarifa": 100,
        "verificado": false, // quedará pendiente para Admin (HU-E3)
        "diasDisponibles": {
          "Lun": false,
          "Mar": true,
          "Mie": true,
          "Jue": false,
          "Vie": true,
          "Sab": true,
          "Dom": false,
        },
        "horaInicio": "10:00",
        "horaFin": "14:00",
      });

      // =========================================
      // 4. MATERIALES DE EJEMPLO (HU-E2, RF4)
      // =========================================

      Future<void> crearMaterialesProfesor(
        String profesorId,
        String profesorNombre,
        String instrumento,
      ) async {
        await firestore.collection("materiales").add({
          "profesorId": profesorId,
          "profesorNombre": profesorNombre,
          "titulo": "Escalas básicas de $instrumento",
          "tipo": "Partitura",
          "descripcion": "PDF con ejercicios iniciales.",
          "fecha": DateTime.now(),
          "urlArchivo": "",
        });

        await firestore.collection("materiales").add({
          "profesorId": profesorId,
          "profesorNombre": profesorNombre,
          "titulo": "Ejercicios rítmicos",
          "tipo": "Audio",
          "descripcion": "MP3 para practicar ritmo en casa.",
          "fecha": DateTime.now(),
          "urlArchivo": "",
        });

        await firestore.collection("materiales").add({
          "profesorId": profesorId,
          "profesorNombre": profesorNombre,
          "titulo": "Clase demostrativa de $instrumento",
          "tipo": "Video",
          "descripcion": "Video corto con técnica básica.",
          "fecha": DateTime.now(),
          "urlArchivo": "",
        });
      }

      await crearMaterialesProfesor(
        profesorGuitarraUid,
        "Ana Guitarra",
        "Guitarra",
      );

      await crearMaterialesProfesor(
        profesorCantoUid,
        "Marcos Vocal Coach",
        "Canto",
      );

      // =========================================
      // 5. RESERVAS (HU-C2, HU-C3, HU-E4, RF2, RF3, RF6)
      // =========================================

      final alumno1Uid = emailToUid["alumno1@musi.com"]!;
      final alumno2Uid = emailToUid["alumno2@musi.com"]!;

      final ahora = DateTime.now();

      // Reserva 1: alumno1 con profe guitarra, FUTURA, estado reservada
      await firestore.collection("reservas").add({
        "alumnoId": alumno1Uid,
        "alumnoNombre": "Luis Piano",
        "profesorId": profesorGuitarraUid,
        "profesorNombre": "Ana Guitarra",
        "instrumento": "Guitarra",
        "fecha": ahora.add(const Duration(days: 2)),
        "hora": "19:00",
        "estado": "reservada",
        "notaProfesor": null,
        "alumnoPuedeValorar": false,
        "tarifa": 80,
        "creado": ahora,
      });

      // Reserva 2: alumno1 con profe guitarra, COMPLETADA, con nota, sin reseña aún
      final reserva2Ref = await firestore.collection("reservas").add({
        "alumnoId": alumno1Uid,
        "alumnoNombre": "Luis Piano",
        "profesorId": profesorGuitarraUid,
        "profesorNombre": "Ana Guitarra",
        "instrumento": "Guitarra",
        "fecha": ahora.subtract(const Duration(days: 3)),
        "hora": "18:30",
        "estado": "completada",
        "notaProfesor": "Buen control de ritmo, seguir practicando cambios de acorde.",
        "alumnoPuedeValorar": true, // Alumno verá botón “Valorar”
        "tarifa": 80,
        "creado": ahora.subtract(const Duration(days: 4)),
      });

      // Reserva 3: alumno2 con profe canto, COMPLETADA, ya valorada
      final reserva3Ref = await firestore.collection("reservas").add({
        "alumnoId": alumno2Uid,
        "alumnoNombre": "Carla Canto",
        "profesorId": profesorCantoUid,
        "profesorNombre": "Marcos Vocal Coach",
        "instrumento": "Canto",
        "fecha": ahora.subtract(const Duration(days: 5)),
        "hora": "11:00",
        "estado": "completada",
        "notaProfesor": "Buena afinación, trabajar respiración diafragmática.",
        "alumnoPuedeValorar": false, // ya valoró
        "tarifa": 100,
        "creado": ahora.subtract(const Duration(days: 6)),
      });

      // Reserva 4: alumno2 con profe guitarra, CANCELADA
      await firestore.collection("reservas").add({
        "alumnoId": alumno2Uid,
        "alumnoNombre": "Carla Canto",
        "profesorId": profesorGuitarraUid,
        "profesorNombre": "Ana Guitarra",
        "instrumento": "Guitarra",
        "fecha": ahora.subtract(const Duration(days: 1)),
        "hora": "20:00",
        "estado": "cancelada",
        "notaProfesor": null,
        "alumnoPuedeValorar": false,
        "tarifa": 80,
        "creado": ahora.subtract(const Duration(days: 2)),
      });

      // =========================================
      // 6. RESEÑAS (HU-C4, RF5)
      // =========================================

      // Reseña sobre profe canto (reserva 3)
      await firestore.collection("reseñas").add({
        "profesorId": profesorCantoUid,
        "alumnoId": alumno2Uid,
        "rating": 5,
        "comentario": "Excelente clase, explica con paciencia y corrige bien la técnica.",
        "fecha": ahora.subtract(const Duration(days: 4)),
      });

      // Reseña sobre profe guitarra (extra)
      await firestore.collection("reseñas").add({
        "profesorId": profesorGuitarraUid,
        "alumnoId": alumno1Uid,
        "rating": 4,
        "comentario": "Muy buena profesora, solo faltó tiempo para ver más temas.",
        "fecha": ahora.subtract(const Duration(days: 1)),
      });

      // Como ejemplo, marcamos la reserva 3 como ya valorada (alumnoPuedeValorar = false)
      await reserva3Ref.update({
        "alumnoPuedeValorar": false,
      });

      // Opcional: podrías vincular reserva2 también a reseña si quisieras.

      setState(() {
        mensaje = "Datos cargados correctamente 🎉\n"
            "Usuarios, profesores, materiales, reservas y reseñas listos.";
      });
    } catch (e) {
      setState(() {
        mensaje = "Error durante el seeding: $e";
      });
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cargar datos de prueba — MusiClase")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "Seeder de datos MusiClase",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Esto creará usuarios, profesores, materiales, reservas y reseñas de ejemplo.",
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: loading ? null : cargarDatos,
                icon: const Icon(Icons.cloud_upload),
                label: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Cargar datos de prueba"),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              mensaje,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
