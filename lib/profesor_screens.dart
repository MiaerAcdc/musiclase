import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';

// ============================================================================
// ROOT PROFESOR
// ============================================================================

class ProfesorRoot extends StatefulWidget {
  const ProfesorRoot({super.key});

  @override
  State<ProfesorRoot> createState() => _ProfesorRootState();
}

class _ProfesorRootState extends State<ProfesorRoot> {
  int index = 0;

  final pages = const [
    ProfesorAgenda(),
    DisponibilidadTarifasProfesor(),
    MaterialesProfesor(),
  ];

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
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
        title: const Text("Profesor — MusiClase"),
        actions: [
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event), label: "Agenda"),
          NavigationDestination(icon: Icon(Icons.settings), label: "Disponibilidad"),
          NavigationDestination(
              icon: Icon(Icons.library_music), label: "Materiales"),
        ],
      ),
    );
  }
}

// ============================================================================
// AGENDA DEL PROFESOR
// ============================================================================

class ProfesorAgenda extends StatelessWidget {
  const ProfesorAgenda({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reservas")
          .where("profesorId", isEqualTo: uid)
          .orderBy("fecha")
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No tienes reservas aún."));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: docs.map((d) {
            final r = d.data() as Map<String, dynamic>;
            final fecha = (r["fecha"] as Timestamp).toDate();

            return Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text("Alumno: ${r['alumnoNombre'] ?? 'N/A'}"),
                subtitle: Text(
                  "${fecha.day}/${fecha.month}/${fecha.year} • ${r['hora']}\n"
                  "Estado: ${r['estado']}",
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ============================================================================
// DISPONIBILIDAD + TARIFAS PROFESOR (HU-E1)
// ============================================================================

class DisponibilidadTarifasProfesor extends StatefulWidget {
  const DisponibilidadTarifasProfesor({super.key});

  @override
  State<DisponibilidadTarifasProfesor> createState() =>
      _DisponibilidadTarifasProfesorState();
}

class _DisponibilidadTarifasProfesorState
    extends State<DisponibilidadTarifasProfesor> {
  double tarifa = 60;
  final dias = {
    "Lun": false,
    "Mar": false,
    "Mie": false,
    "Jue": false,
    "Vie": false,
    "Sab": false,
    "Dom": false,
  };

  TimeOfDay inicio = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay fin = const TimeOfDay(hour: 21, minute: 0);

  bool loading = false;

  Future<void> pickInicio() async {
    final t = await showTimePicker(context: context, initialTime: inicio);
    if (t != null) setState(() => inicio = t);
  }

  Future<void> pickFin() async {
    final t = await showTimePicker(context: context, initialTime: fin);
    if (t != null) setState(() => fin = t);
  }

  Future<void> guardar() async {
    setState(() => loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance.collection("profesores").doc(uid).set({
        "tarifa": tarifa,
        "diasDisponibles": dias,
        "horaInicio": "${inicio.hour}:${inicio.minute}",
        "horaFin": "${fin.hour}:${fin.minute}",
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Datos guardados")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Disponibilidad y Tarifas",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        const Text("Días disponibles"),
        Wrap(
          spacing: 8,
          children: dias.keys.map((d) {
            return FilterChip(
              label: Text(d),
              selected: dias[d]!,
              onSelected: (v) => setState(() => dias[d] = v),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text("Horario habitual"),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                child: Text("Inicio: ${inicio.format(context)}"),
                onPressed: pickInicio,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                child: Text("Fin: ${fin.format(context)}"),
                onPressed: pickFin,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text("Tarifa por hora"),
        Slider(
          min: 30,
          max: 150,
          value: tarifa,
          label: tarifa.toStringAsFixed(0),
          onChanged: (v) => setState(() => tarifa = v),
        ),
        Text("S/ ${tarifa.toStringAsFixed(0)}", textAlign: TextAlign.right),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: loading ? null : guardar,
            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Guardar"),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// MATERIALES DEL PROFESOR (HU-E2)
// ============================================================================

class MaterialesProfesor extends StatefulWidget {
  const MaterialesProfesor({super.key});

  @override
  State<MaterialesProfesor> createState() => _MaterialesProfesorState();
}

class _MaterialesProfesorState extends State<MaterialesProfesor> {
  void abrirFormulario() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: const FormularioMaterial(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("materiales")
            .where("profesorId", isEqualTo: uid)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                "Tus materiales",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              if (docs.isEmpty)
                const Text("Aún no has subido materiales"),
              ...docs.map((d) {
                final m = d.data() as Map<String, dynamic>;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      m["tipo"] == "Audio"
                          ? Icons.audiotrack
                          : m["tipo"] == "Video"
                              ? Icons.play_circle
                              : Icons.description,
                    ),
                    title: Text(m["titulo"] ?? ""),
                    subtitle: Text(m["descripcion"] ?? ""),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection("materiales")
                            .doc(d.id)
                            .delete();
                      },
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: abrirFormulario,
        icon: const Icon(Icons.upload_file),
        label: const Text("Nuevo material"),
      ),
    );
  }
}

// ============================================================================
// FORMULARIO SUBIR MATERIAL
// ============================================================================

class FormularioMaterial extends StatefulWidget {
  const FormularioMaterial({super.key});

  @override
  State<FormularioMaterial> createState() => _FormularioMaterialState();
}

class _FormularioMaterialState extends State<FormularioMaterial> {
  final titulo = TextEditingController();
  final descripcion = TextEditingController();
  String tipo = "Partitura";
  bool loading = false;

  Future<void> guardar() async {
    if (titulo.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Ingresa un título")));
      return;
    }

    setState(() => loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance.collection("materiales").add({
        "profesorId": uid,
        "profesorNombre": FirebaseAuth.instance.currentUser!.email ?? "",
        "titulo": titulo.text.trim(),
        "tipo": tipo,
        "descripcion": descripcion.text.trim(),
        "fecha": DateTime.now(),
        "urlArchivo": null,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Material guardado")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Nuevo material",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: titulo,
          decoration: const InputDecoration(
            labelText: "Título",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField(
          value: tipo,
          items: const [
            DropdownMenuItem(value: "Partitura", child: Text("Partitura")),
            DropdownMenuItem(value: "Audio", child: Text("Audio")),
            DropdownMenuItem(value: "Video", child: Text("Video")),
            DropdownMenuItem(value: "PDF", child: Text("PDF")),
          ],
          onChanged: (v) => setState(() => tipo = v!),
          decoration: const InputDecoration(
            labelText: "Tipo",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descripcion,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: "Descripción",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: loading ? null : guardar,
            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Guardar"),
          ),
        ),
      ],
    );
  }
}
