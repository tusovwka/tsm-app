import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../game/log.dart";
import "../game/player.dart";
import "../utils/game_controller.dart";

class JudgeRatingScreen extends StatefulWidget {
  final Map<int, double>? initialRatings;
  
  const JudgeRatingScreen({super.key, this.initialRatings});

  @override
  State<JudgeRatingScreen> createState() => _JudgeRatingScreenState();
}

class _JudgeRatingScreenState extends State<JudgeRatingScreen> {
  late Map<int, double> _ratings;

  @override
  void initState() {
    super.initState();
    final controller = context.read<GameController>();
    _ratings = {};
    
    // Инициализируем оценки
    for (var i = 1; i <= 10; i++) {
      if (widget.initialRatings != null && widget.initialRatings!.containsKey(i)) {
        _ratings[i] = widget.initialRatings![i]!;
      } else {
        // Получаем информацию об игроке
        final hadPPK = _checkIfPlayerHadPPK(i);
        final player = controller.players.getByNumber(i);
        final wasKicked = player.state.isKicked;
        
        if (hadPPK) {
          _ratings[i] = -2.5;
        } else if (wasKicked) {
          _ratings[i] = 1.5;
        } else {
          _ratings[i] = 2.5;
        }
      }
    }
  }

  bool _checkIfPlayerHadPPK(int playerNumber) {
    // Проверяем есть ли в логе PlayerKickedGameLogItem с isOtherTeamWin: true для этого игрока
    final controller = context.read<GameController>();
    for (final logItem in controller.gameLog) {
      if (logItem is PlayerKickedGameLogItem && 
          logItem.playerNumber == playerNumber && 
          logItem.isOtherTeamWin == true) {
        return true;
      }
    }
    return false;
  }

  double _getMinRating(int playerNumber) {
    final hadPPK = _checkIfPlayerHadPPK(playerNumber);
    final controller = context.read<GameController>();
    final player = controller.players.getByNumber(playerNumber);
    
    if (hadPPK || player.state.isKicked) {
      return -2.0;
    }
    return 0.0;
  }

  double _getMaxRating(int playerNumber) {
    final hadPPK = _checkIfPlayerHadPPK(playerNumber);
    final controller = context.read<GameController>();
    final player = controller.players.getByNumber(playerNumber);
    
    if (hadPPK || player.state.isKicked) {
      return 4.0;
    }
    return 5.0;
  }

  void _changeRating(int playerNumber, double delta) {
    setState(() {
      final newRating = (_ratings[playerNumber]! + delta);
      final min = _getMinRating(playerNumber);
      final max = _getMaxRating(playerNumber);
      _ratings[playerNumber] = newRating.clamp(min, max);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Оценка судей"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: "Сохранить",
            onPressed: () {
              Navigator.pop(context, _ratings);
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 10,
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, index) {
          final playerNumber = index + 1;
          final player = controller.players.getByNumber(playerNumber);
          final hadPPK = _checkIfPlayerHadPPK(playerNumber);
          final rating = _ratings[playerNumber]!;
          final min = _getMinRating(playerNumber);
          final max = _getMaxRating(playerNumber);
          
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: isMobile ? _buildMobileRatingCard(
                context, playerNumber, player, hadPPK, rating, min, max,
              ) : _buildDesktopRatingCard(
                context, playerNumber, player, hadPPK, rating, min, max,
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildDesktopRatingCard(
    BuildContext context,
    int playerNumber,
    Player player,
    bool hadPPK,
    double rating,
    double min,
    double max,
  ) {
    return Row(
      children: [
        // Номер и имя игрока
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Игрок $playerNumber",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (player.nickname != null)
                Text(
                  player.nickname!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (hadPPK)
                Text(
                  "ППК",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (player.state.isKicked)
                Text(
                  "Удалён",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ),
        // Кнопки управления оценкой
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: hadPPK ? null : (rating > min ? () => _changeRating(playerNumber, -0.25) : null),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  rating.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hadPPK ? Colors.red : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: hadPPK ? null : (rating < max ? () => _changeRating(playerNumber, 0.25) : null),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMobileRatingCard(
    BuildContext context,
    int playerNumber,
    Player player,
    bool hadPPK,
    double rating,
    double min,
    double max,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Игрок $playerNumber",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (player.nickname != null)
                  Text(
                    player.nickname!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            if (hadPPK)
              Text(
                "ППК",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              )
            else if (player.state.isKicked)
              Text(
                "Удалён",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Оценка и слайдер
        Row(
          children: [
            Expanded(
              child: Slider(
                value: rating,
                min: min,
                max: max,
                divisions: ((max - min) / 0.25).round(),
                label: rating.toStringAsFixed(2),
                onChanged: hadPPK ? null : (value) {
                  setState(() {
                    _ratings[playerNumber] = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: Text(
                rating.toStringAsFixed(2),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: hadPPK ? Colors.red : null,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

