import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../utils/db/models.dart" as db_models;
import "../utils/db/repo.dart";
import "../utils/log.dart";
import "../utils/navigation.dart";
import "../utils/ui.dart";
import "../widgets/confirmation_dialog.dart";


class _PlayerTile extends StatelessWidget {
  final db_models.Player player;
  final VoidCallback onTap;

  const _PlayerTile({
    required this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.person),
        title: Text(player.nickname),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (player.realName.isNotEmpty) Text(player.realName),
            if (player.memberId != null) 
              Text("ID: ${player.memberId}", style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        onTap: onTap,
      );
}

class PlayersScreen extends StatelessWidget {
  static final _log = Logger("PlayersScreen");

  const PlayersScreen({super.key});


  Future<void> _onSearchPressed(BuildContext context, PlayerRepo players) async {
    final result = await showSearch(
      context: context,
      delegate: _PlayerSearchDelegate(players.data),
    );
    if (result == null || !context.mounted) {
      return;
    }
    await openPlayerInfoPage(context, result);
  }

  void _onLoadFromJsonError(BuildContext context, Object error, StackTrace stackTrace) {
    showSnackBar(context, const SnackBar(content: Text("Ошибка загрузки игроков")));
    _log.error("Error loading player list: e=$error\n$stackTrace");
  }



  Future<void> _onSyncWithApiPressed(BuildContext context, PlayerRepo players) async {
    try {
      final updatedCount = await players.syncWithApi();
      if (!context.mounted) {
        return;
      }
      showSnackBar(
        context,
        SnackBar(
          content: Text(
            updatedCount > 0 
                ? "Синхронизировано $updatedCount игроков" 
                : "Список игроков актуален",
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      showSnackBar(
        context,
        SnackBar(
          content: Text("Ошибка синхронизации: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
      _log.error("Error syncing with API: $e");
    }
  }

  Future<void> _onLoadFromApiPressed(BuildContext context, PlayerRepo players) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: const Text("Загрузить игроков из API?"),
        content: const Text("Это заменит всех текущих игроков данными из API."),
      ),
    );
    if (confirmed ?? false) {
      try {
        await players.loadFromApi();
        if (!context.mounted) {
          return;
        }
        showSnackBar(
          context,
          const SnackBar(content: Text("Игроки загружены из API")),
        );
      } catch (e) {
        if (!context.mounted) {
          return;
        }
        showSnackBar(
          context,
          SnackBar(
            content: Text("Ошибка загрузки из API: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
        _log.error("Error loading from API: $e");
      }
    }
  }

  Future<void> _onClearPressed(BuildContext context, PlayerRepo players) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: const Text("Удалить всех игроков?"),
        content: const Text("Вы уверены, что хотите удалить всех игроков?"),
      ),
    );
    if (confirmed ?? false) {
      await players.clear();
      if (!context.mounted) {
        return;
      }
      showSnackBar(context, const SnackBar(content: Text("Все игроки удалены")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = context.watch<PlayerRepo>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Игроки"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Искать",
            onPressed: () => _onSearchPressed(context, players),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: "Синхронизировать с API",
            onPressed: () => _onSyncWithApiPressed(context, players),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: "Загрузить из API",
            onPressed: () => _onLoadFromApiPressed(context, players),
          ),
        ],
      ),
      body: players.data.isNotEmpty
          ? ListView.builder(
              itemCount: players.data.length + 1,
              itemBuilder: (context, index) {
                if (index == players.data.length) {
                  return ListTile(
                    title: Text(
                      "Всего игроков: ${players.data.length}",
                      textAlign: TextAlign.center,
                    ),
                    dense: true,
                    enabled: false,
                    titleAlignment: ListTileTitleAlignment.center,
                  );
                }
                final (key, player) = players.data[index];
                return _PlayerTile(
                  player: player,
                  onTap: () => openPlayerInfoPage(context, key),
                );
              },
            )
          : const Center(child: Text("Список игроков пуст")),
    );
  }
}

class _PlayerSearchDelegate extends SearchDelegate<String> {
  final List<WithID<db_models.Player>> data;

  _PlayerSearchDelegate(this.data) : super(searchFieldLabel: "Никнейм");

  List<WithID<db_models.Player>> get filteredData => data.where((e) {
        final p = e.$2;
        final q = query.toLowerCase();
        return p.nickname.toLowerCase().contains(q) || p.realName.toLowerCase().contains(q);
      }).toList();

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(onPressed: () => query = "", icon: const Icon(Icons.clear)),
      ];

  @override
  Widget? buildLeading(BuildContext context) => const BackButton();

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = filteredData;
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final (key, player) = results[index];
        return _PlayerTile(
          player: player,
          onTap: () => close(context, key),
        );
      },
    );
  }
}
