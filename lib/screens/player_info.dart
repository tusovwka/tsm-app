import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "../utils/db/repo.dart";
import "../utils/log.dart";

class PlayerInfoScreen extends StatelessWidget {
  static final _log = Logger("PlayerInfoScreen");

  final String playerID;

  const PlayerInfoScreen({
    super.key,
    required this.playerID,
  });

  @override
  Widget build(BuildContext context) {
    final players = context.watch<PlayerRepo>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Статистика игрока"),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: "Открыть в браузере",
            onPressed: () => _openInBrowser(context, players),
          ),
        ],
      ),
      body: FutureBuilder(
        future: players.get(playerID),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.requireData == null) {
            _log.error("Player $playerID not found");
            return const Center(child: Text("Игрок не найден"));
          }
          final pws = snapshot.requireData!;
          
          if (pws.player.memberId == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, size: 64, color: Colors.orange),
                  SizedBox(height: 16),
                  Text("Статистика недоступна"),
                  SizedBox(height: 8),
                  Text("У игрока отсутствует member_id"),
                ],
              ),
            );
          }
          
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.web, size: 64),
                SizedBox(height: 16),
                Text("Статистика игрока"),
                SizedBox(height: 8),
                Text("Откройте в браузере для просмотра"),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openInBrowser(BuildContext context, PlayerRepo players) async {
    final playerData = await players.get(playerID);
    if (playerData?.player.memberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("У игрока отсутствует member_id")),
      );
      return;
    }
    
    final url = Uri.parse("https://mafia.tusovwka.ru/players/${playerData!.player.memberId}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось открыть ссылку")),
      );
    }
  }
}