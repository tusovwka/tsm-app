import "package:hive_flutter/hive_flutter.dart";

import "adapters.dart";
import "models.dart";
// import "../notes/note.dart"; // Temporarily commented out

Future<void> init() async {
  await Hive.initFlutter();
  Hive
    ..registerAdapter(PlayerRoleAdapter())
    ..registerAdapter(PlayerAdapter())
    ..registerAdapter(PlayerStatsAdapter());
    // TODO: Register NoteAdapter when note.g.dart is available in build environment
    // ..registerAdapter(NoteAdapter());
  await Hive.openBox<Player>("players");
  await Hive.openBox<Player>("players2");
  await Hive.openBox<PlayerStats>("playerStats");
  // await Hive.openBox<Note>("notes"); // Temporarily disabled
}
