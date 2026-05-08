import 'package:flutter/material.dart';
import '../migrate_realtime_to_firestore.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  String status = "Presiona el botón para migrar";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Migración de datos")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  status = "Migrando...";
                });

                try {
                  await MigratorPro().migrarTodo();
                  setState(() {
                    status = "Migración completada";
                  });
                } catch (e) {
                  setState(() {
                    status = "Error: $e";
                  });
                }
              },
              child: const Text("MIGRAR DATOS"),
            ),
          ],
        ),
      ),
    );
  }
}
