import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';

/// ROOT DEL GESTOR
class GestorRoot extends StatelessWidget {
  const GestorRoot({super.key});

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
        title: const Text("Gestor — MusiClase"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: const GestorReportes(),
    );
  }
}

/// PANTALLA: Reportes reservas/ganancias (HU-E4 / RF6)
class GestorReportes extends StatefulWidget {
  const GestorReportes({super.key});

  @override
  State<GestorReportes> createState() => _GestorReportesState();
}

class _GestorReportesState extends State<GestorReportes> {
  DateTimeRange? rangoFechas;

  Future<void> _seleccionarRango() async {
    final hoy = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: hoy.subtract(const Duration(days: 90)),
      lastDate: hoy.add(const Duration(days: 90)),
      initialDateRange: rangoFechas ??
          DateTimeRange(
            start: hoy.subtract(const Duration(days: 7)),
            end: hoy,
          ),
    );
    if (picked != null) {
      setState(() => rangoFechas = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseQuery = FirebaseFirestore.instance.collection("reservas");
    final stream = rangoFechas == null
        ? baseQuery.snapshots()
        : baseQuery
            .where("fecha", isGreaterThanOrEqualTo: rangoFechas!.start)
            .where("fecha", isLessThanOrEqualTo: rangoFechas!.end)
            .snapshots();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            "Reportes de reservas y ganancias",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _seleccionarRango,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    rangoFechas == null
                        ? "Elegir rango de fechas"
                        : "${rangoFechas!.start.day}/${rangoFechas!.start.month} - "
                          "${rangoFechas!.end.day}/${rangoFechas!.end.month}",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text("No hay reservas en el rango seleccionado."),
                  );
                }

                // Agregados por profesor
                final Map<String, Map<String, dynamic>> agregados = {};
                for (final d in docs) {
                  final r = d.data() as Map<String, dynamic>;
                  final profId = (r["profesorId"] ?? "sin") as String;
                  final profNombre =
                      (r["profesorNombre"] ?? "Profesor") as String;
                  final tarifa = (r["tarifa"] ?? 0).toDouble();

                  agregados.putIfAbsent(profId, () {
                    return {
                      "profesorNombre": profNombre,
                      "reservas": 0,
                      "ganancias": 0.0,
                    };
                  });

                  agregados[profId]!["reservas"] =
                      (agregados[profId]!["reservas"] as int) + 1;
                  agregados[profId]!["ganancias"] =
                      (agregados[profId]!["ganancias"] as double) + tarifa;
                }

                final totalReservas = agregados.values.fold<int>(
                    0, (sum, e) => sum + (e["reservas"] as int));
                final totalGanancias = agregados.values.fold<double>(
                    0.0, (sum, e) => sum + (e["ganancias"] as double));

                final lista = agregados.values.toList();

                return ListView(
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.summarize),
                        title: const Text("Resumen general"),
                        subtitle: Text(
                          "Total reservas: $totalReservas\n"
                          "Total ganancias: S/ ${totalGanancias.toStringAsFixed(0)}",
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Detalle por profesor",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text("Profesor")),
                          DataColumn(label: Text("Reservas")),
                          DataColumn(label: Text("Ganancias (S/.)")),
                        ],
                        rows: lista.map((e) {
                          final nombre =
                              (e["profesorNombre"] as String?) ?? "Profesor";
                          final cant = (e["reservas"] as int?) ?? 0;
                          final gan =
                              (e["ganancias"] as double?)?.toStringAsFixed(0) ??
                                  "0";
                          return DataRow(cells: [
                            DataCell(Text(nombre)),
                            DataCell(Text("$cant")),
                            DataCell(Text(gan)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
