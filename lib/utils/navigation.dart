import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../game/log.dart";
import "../screens/choose_roles_screen.dart";
import "deck_mode_provider.dart";
import "../screens/debug_menu_screen.dart";
import "../screens/game_log.dart";
import "../screens/judge_rating.dart";
import "../screens/player_info.dart";
import "../screens/player_stats.dart";
import "../screens/players.dart";
import "../screens/roles.dart";
import "../screens/seat_randomizer.dart";
import "../screens/timeout.dart";
import "../screens/settings/appearance.dart";
import "../screens/settings/behavior.dart";
import "../screens/settings/main.dart";
import "../screens/settings/rules.dart";

Future<void> openPage(BuildContext context, Widget page) async {
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => page));
}

Future<void> openRoleChooserPage(BuildContext context) {
  final deckModeProvider = context.read<DeckModeProvider>();
  return openPage(context, ChooseRolesScreen(initialDeckMode: deckModeProvider.isDeckMode));
}

Future<void> openDebugMenuPage(BuildContext context) => openPage(context, const DebugMenuScreen());

Future<void> openGameLogPage(BuildContext context, [List<BaseGameLogItem>? log]) =>
    openPage(context, GameLogScreen(log: log));

Future<void> openPlayerInfoPage(BuildContext context, String playerID) =>
    openPage(context, PlayerInfoScreen(playerID: playerID));

Future<void> openPlayerStatsPage(BuildContext context, String playerID) =>
    openPage(context, PlayerStatsScreen(playerID: playerID));

Future<void> openPlayersPage(BuildContext context) => openPage(context, const PlayersScreen());

Future<void> openRolesPage(BuildContext context) => openPage(context, const RolesScreen());

Future<void> openSeatRandomizerPage(BuildContext context) =>
    openPage(context, const SeatRandomizerScreen());

Future<void> openTimeoutPage(BuildContext context) => openPage(context, const TimeoutScreen());

Future<Map<int, double>?> openJudgeRatingPage(BuildContext context, {Map<int, double>? initialRatings}) async {
  return await Navigator.of(context).push<Map<int, double>>(
    MaterialPageRoute(builder: (context) => JudgeRatingScreen(initialRatings: initialRatings)),
  );
}

enum SettingsSubpage {
  appearance,
  behavior,
  rules,
}

Future<void> openSettingsPage(BuildContext context, [SettingsSubpage? subpage]) => openPage(
      context,
      switch (subpage) {
        SettingsSubpage.appearance => const AppearanceSettingsScreen(),
        SettingsSubpage.behavior => const BehaviorSettingsScreen(),
        SettingsSubpage.rules => const GameRulesSettingsScreen(),
        null => const SettingsScreen(),
      },
    );
