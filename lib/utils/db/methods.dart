import "package:hive_flutter/hive_flutter.dart";

import "adapters.dart";
import "models.dart";
import "../notes/note.dart";

Future<void> init() async {
  await Hive.initFlutter();
  Hive
    ..registerAdapter(PlayerRoleAdapter())
    ..registerAdapter(PlayerAdapter())
    ..registerAdapter(PlayerStatsAdapter())
    ..registerAdapter(NoteAdapter());
  await Hive.openBox<Player>("players");
  await Hive.openBox<Player>("players2");
  await Hive.openBox<PlayerStats>("playerStats");
  await Hive.openBox<Note>("notes");
}
