import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MigratorPro {
  final realtime = FirebaseDatabase.instance.ref();
  final firestore = FirebaseFirestore.instance;

  final String ligaId = "liga_1";

  Map<String, dynamic> convertirAMap(dynamic data) {
    if (data == null) return {};

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is List) {
      Map<String, dynamic> mapa = {};
      for (int i = 0; i < data.length; i++) {
        if (data[i] != null) {
          mapa[i.toString()] = data[i];
        }
      }
      return mapa;
    }

    return {};
  }

  Future<void> migrarTodo() async {
    print("==== INICIANDO MIGRACIÓN PRO ====");

    final temporadasSnap = await realtime.child("temporadas").get();
    final temporadas = convertirAMap(temporadasSnap.value);

    for (var temporadaKey in temporadas.keys) {
      String temporadaId = temporadaKey.toString();
      final temporadaData = convertirAMap(temporadas[temporadaKey]);

      // =====================
      // TEMPORADA (TOP LEVEL)
      // =====================
      await firestore.collection("temporadas").doc(temporadaId).set({
        "ligaId": ligaId,
        "nombre": temporadaData["nombre"],
        "numero": temporadaData["numero"],
        "isActive": temporadaData["isActive"],
        "createdAt": temporadaData["createdAt"],
      });

      print("Temporada $temporadaId migrada");

      // =====================
      // EQUIPOS (TOP LEVEL)
      // =====================
      final teams = convertirAMap(temporadaData["teams"]);

      for (var teamId in teams.keys) {
        final teamData = convertirAMap(teams[teamId]);

        final teamRef = firestore.collection("equipos").doc(teamId);

        await teamRef.set({
          "ligaId": ligaId,
          "temporadaId": temporadaId,
          "nombre": teamData["name"],
          "color": teamData["color"],
          "logoUrl": teamData["logoUrl"],
          "PJ": teamData["played"] ?? 0,
          "PG": teamData["wins"] ?? 0,
          "PE": teamData["draws"] ?? 0,
          "PP": teamData["losses"] ?? 0,
          "GF": teamData["goalsFor"] ?? 0,
          "GC": teamData["goalsAgainst"] ?? 0,
          "Pts": teamData["points"] ?? 0,
        });

        print("Equipo $teamId migrado");

        // JUGADORES (SUBCOLECCIÓN)
        final players = convertirAMap(teamData["players"]);

        for (var playerId in players.keys) {
          final playerData = convertirAMap(players[playerId]);

          await teamRef.collection("jugadores").doc(playerId).set({
            "equipoId": teamId,
            "temporadaId": temporadaId,
            "ligaId": ligaId,
            "nombre": playerData["name"],
            "numero": playerData["number"].toString(),
            "goles": playerData["goals"] ?? 0,
            "fotoUrl": playerData["photoUrl"],
            "createdAt": playerData["createdAt"],
          });

          print("Jugador $playerId migrado");
        }
      }

      // =====================
      // JORNADAS (TOP LEVEL)
      // =====================
      final jornadas = convertirAMap(temporadaData["jornadas"]);

      for (var jornadaId in jornadas.keys) {
        final jornadaData = convertirAMap(jornadas[jornadaId]);

        final jornadaRef = firestore.collection("jornadas").doc(jornadaId);

        await jornadaRef.set({
          "ligaId": ligaId,
          "temporadaId": temporadaId,
          "numero": jornadaData["numero"],
          "createdAt": jornadaData["createdAt"],
        });

        print("Jornada $jornadaId migrada");

        // PARTIDOS (SUBCOLECCIÓN)
        final partidos = convertirAMap(jornadaData["partidos"]);

        for (var partidoId in partidos.keys) {
          final partido = convertirAMap(partidos[partidoId]);

          await jornadaRef.collection("partidos").doc().set({
            "ligaId": ligaId,
            "temporadaId": temporadaId,
            "jornadaId": jornadaId,
            "equipo1Id": partido["equipo1Id"],
            "equipo1Nombre": partido["equipo1Nombre"],
            "equipo2Id": partido["equipo2Id"],
            "equipo2Nombre": partido["equipo2Nombre"],
            "golesEquipo1": partido["golesEquipo1"],
            "golesEquipo2": partido["golesEquipo2"],
            "penales": partido["penales"] ?? false,
            "ganadorPenalesId": partido["ganadorPenales"],
            "fecha": partido["fecha"],
            "hora": partido["hora"],
            "jugado": partido["golesEquipo1"] != null,
            "createdAt": DateTime.now().toIso8601String(),
          });

          print("Partido migrado");
        }
      }
    }

    print("==== MIGRACIÓN PRO COMPLETADA ====");
  }
}
