import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';

// ============================================================================
// ROOT DEL ALUMNO
// ============================================================================

class AlumnoRoot extends StatefulWidget {
  const AlumnoRoot({super.key});

  @override
  State<AlumnoRoot> createState() => _AlumnoRootState();
}

class _AlumnoRootState extends State<AlumnoRoot> {
  int index = 0;

  final pages = const [
    BuscarProfesores(),
    MisClasesAlumno(),
    BibliotecaAlumno(),
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
        title: const Text("Alumno — MusiClase"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: logout),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: "Profesores"),
          NavigationDestination(icon: Icon(Icons.event), label: "Mis clases"),
          NavigationDestination(
              icon: Icon(Icons.library_music), label: "Biblioteca"),
        ],
      ),
    );
  }
}

// ============================================================================
// BUSCAR PROFESORES (HU-C1)
// ============================================================================

class BuscarProfesores extends StatefulWidget {
  const BuscarProfesores({super.key});
  @override
  State<BuscarProfesores> createState() => _BuscarProfesoresState();
}

class _BuscarProfesoresState extends State<BuscarProfesores> {
  final txt = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final query = txt.text.toLowerCase();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: txt,
            decoration: const InputDecoration(
              labelText: "Buscar por nombre o instrumento",
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("profesores")
                  .where("verificado", isEqualTo: true)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final nombre = (data["nombre"] ?? "").toLowerCase();
                      final inst = (data["instrumento"] ?? "").toLowerCase();
                      return nombre.contains(query) || inst.contains(query);
                    }).toList() ??
                    [];

                if (docs.isEmpty) {
                  return const Center(
                      child: Text("No se encontraron profesores."));
                }

                return ListView(
                  children: docs.map((d) {
                    final p = d.data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                            child: Text((p["nombre"] ?? "?")[0])),
                        title:
                            Text("${p['nombre'] ?? ''} • ${p['instrumento'] ?? ''}"),
                        subtitle: Text(
                            "S/${p['tarifa'] ?? 0} • ${p['modalidad'] ?? ''}"),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DetalleProfesor(idProfesor: d.id, data: p),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DETALLE PROFESOR + RESERVA
// ============================================================================

class DetalleProfesor extends StatefulWidget {
  final String idProfesor;
  final Map<String, dynamic> data;

  const DetalleProfesor({
    super.key,
    required this.idProfesor,
    required this.data,
  });

  @override
  State<DetalleProfesor> createState() => _DetalleProfesorState();
}

class _DetalleProfesorState extends State<DetalleProfesor> {
  DateTime? fecha;
  String? hora;

  final horarios = ["18:00", "19:00", "20:00"];

  Future<void> seleccionarFecha() async {
    final f = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (f != null) setState(() => fecha = f);
  }

  void continuarPago() {
    if (fecha == null || hora == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Selecciona fecha y hora")));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PagoSimulado(
          idProfesor: widget.idProfesor,
          profData: widget.data,
          fecha: fecha!,
          hora: hora!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.data;

    return Scaffold(
      appBar: AppBar(title: Text(p["nombre"] ?? "Profesor")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              CircleAvatar(
                radius: 30,
                child: Text((p["nombre"] ?? "?")[0]),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p["nombre"] ?? "",
                    style: const TextStyle(fontSize: 18)),
                Text("${p['instrumento'] ?? ''} • ${p['modalidad'] ?? ''}"),
                Text("S/${p['tarifa'] ?? 0}"),
              ]),
            ]),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text(
                fecha == null
                    ? "Seleccionar fecha"
                    : "${fecha!.day}/${fecha!.month}/${fecha!.year}",
              ),
              onPressed: seleccionarFecha,
            ),
            if (fecha != null) ...[
              const SizedBox(height: 12),
              const Text("Horarios disponibles"),
              Wrap(
                spacing: 8,
                children: horarios.map((h) {
                  return ChoiceChip(
                    label: Text(h),
                    selected: hora == h,
                    onSelected: (_) => setState(() => hora = h),
                  );
                }).toList(),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.payment),
                  label: const Text("Reservar y pagar"),
                  onPressed: continuarPago,
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PAGO SIMULADO
// ============================================================================

class PagoSimulado extends StatefulWidget {
  final String idProfesor;
  final Map<String, dynamic> profData;
  final DateTime fecha;
  final String hora;

  const PagoSimulado({
    super.key,
    required this.idProfesor,
    required this.profData,
    required this.fecha,
    required this.hora,
  });

  @override
  State<PagoSimulado> createState() => _PagoSimuladoState();
}

class _PagoSimuladoState extends State<PagoSimulado> {
  String metodo = "Tarjeta";

  Future<void> confirmar() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance.collection("reservas").add({
        "alumnoId": uid,
        "profesorId": widget.idProfesor,
        "profesorNombre": widget.profData["nombre"],
        "instrumento": widget.profData["instrumento"],
        "fecha": widget.fecha,
        "hora": widget.hora,
        "estado": "reservada",
        "alumnoPuedeValorar": false,
        "notaProfesor": null,
        "creado": DateTime.now(),
        "tarifa": widget.profData["tarifa"],
      });

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reserva confirmada")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profData;

    return Scaffold(
      appBar: AppBar(title: const Text("Pago simulado")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(p["nombre"] ?? ""),
                subtitle: Text(
                    "${widget.fecha.day}/${widget.fecha.month} • ${widget.hora}"),
                trailing: Text("S/${p['tarifa'] ?? 0}"),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Método de pago"),
            RadioListTile(
              value: "Tarjeta",
              groupValue: metodo,
              title: const Text("Tarjeta"),
              onChanged: (v) => setState(() => metodo = v!),
            ),
            RadioListTile(
              value: "Yape/Plin",
              groupValue: metodo,
              title: const Text("Yape / Plin"),
              onChanged: (v) => setState(() => metodo = v!),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                child: const Text("Confirmar"),
                onPressed: confirmar,
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MIS CLASES (Arreglado 100%) HU-C3 / HU-C4
// ============================================================================

class MisClasesAlumno extends StatelessWidget {
  const MisClasesAlumno({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reservas")
          .where("alumnoId", isEqualTo: uid)
          .orderBy("fecha", descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.hasError) {
          return Center(child: Text("Error: ${snap.error}"));
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text("No tienes clases aún."));
        }

        final docs = snap.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: docs.map((d) {
            final r = d.data() as Map<String, dynamic>;
            final fecha = (r["fecha"] as Timestamp).toDate();

            return Card(
              child: ListTile(
                leading: const Icon(Icons.event),
                title: Text("${r['profesorNombre']} "),
                subtitle: Text(
                  "${fecha.day}/${fecha.month}/${fecha.year} • ${r['hora']}\n"
                  "Estado: ${r['estado']}\n"
                  "Nota: ${r['notaProfesor'] ?? 'Pendiente'}",
                ),
                trailing: r["alumnoPuedeValorar"] == true
                    ? TextButton(
                        child: const Text("Valorar"),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ValorarProfesor(
                                reservaId: d.id,
                                data: r,
                              ),
                            ),
                          );
                        },
                      )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ============================================================================
// VALORAR PROFESOR
// ============================================================================

class ValorarProfesor extends StatefulWidget {
  final String reservaId;
  final Map<String, dynamic> data;

  const ValorarProfesor({
    super.key,
    required this.reservaId,
    required this.data,
  });

  @override
  State<ValorarProfesor> createState() => _ValorarProfesorState();
}

class _ValorarProfesorState extends State<ValorarProfesor> {
  int rating = 5;
  final ctrlComentario = TextEditingController();

  Future<void> guardar() async {
    try {
      await FirebaseFirestore.instance.collection("reseñas").add({
        "profesorId": widget.data["profesorId"],
        "alumnoId": FirebaseAuth.instance.currentUser!.uid,
        "rating": rating,
        "comentario": ctrlComentario.text.trim(),
        "fecha": DateTime.now(),
      });

      await FirebaseFirestore.instance
          .collection("reservas")
          .doc(widget.reservaId)
          .update({"alumnoPuedeValorar": false});

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Reseña guardada")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Valorar profesor")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Puntaje"),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final s = i + 1;
                return IconButton(
                  icon: Icon(rating >= s ? Icons.star : Icons.star_border),
                  onPressed: () => setState(() => rating = s),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrlComentario,
              decoration: const InputDecoration(
                labelText: "Comentario",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: guardar,
                child: const Text("Guardar reseña"),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BIBLIOTECA
// ============================================================================

class BibliotecaAlumno extends StatelessWidget {
  const BibliotecaAlumno({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("materiales")
          .orderBy("titulo")
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No hay materiales disponibles."));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: docs.map((d) {
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
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Abrir ${m['titulo']}")),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
