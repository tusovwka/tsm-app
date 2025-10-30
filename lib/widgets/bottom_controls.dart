import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../game/log.dart";
import "../game/player.dart";
import "../game/states.dart";
import "../utils/db/models.dart";
import "../utils/db/repo.dart";
import "../utils/extensions.dart";
import "../utils/game_controller.dart";
import "../utils/state_change_utils.dart";
import "../utils/ui.dart";
import "confirmation_dialog.dart";

class GameBottomControlBar extends StatelessWidget {
  final VoidCallback? onTapBack;
  final VoidCallback? onTapNext;

  const GameBottomControlBar({
    super.key,
    this.onTapBack,
    this.onTapNext,
  });

  void _onTapBack(GameController controller) {
    controller.setPreviousState();
    onTapBack?.call();
  }

  Future<void> _onTapNext(BuildContext context, GameController controller) async {
    final nextStateAssumption = controller.nextStateAssumption;
    if (nextStateAssumption == null) {
      return;
    }
    
    // Проверяем, если текущее состояние - GameStateBestTurn, показываем диалог ввода Ci
    if (controller.state is GameStateBestTurn) {
      final currentState = controller.state as GameStateBestTurn;
      final playerNumber = currentState.currentPlayerNumber;
      
      // Показываем диалог ввода Ci
      final ci = await _showCiInputDialog(context, playerNumber);
      
      if (!context.mounted) {
        return;
      }
      
      // Если пользователь ввел значение, сохраняем его
      if (ci != null) {
        controller.bestTurnCi ??= {};
        controller.bestTurnCi![playerNumber] = ci;
      }
    }
    
    controller.setNextState();
    onTapNext?.call();
  }
  
  Future<double?> _showCiInputDialog(BuildContext context, int playerNumber) async {
    double currentValue = 0.0;
    
    return showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Ci для игрока #$playerNumber"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Введите коэффициент интереса (Ci):"),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: currentValue > 0
                        ? () => setState(() => currentValue = (currentValue - 0.5).clamp(0.0, double.infinity))
                        : null,
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      currentValue.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => currentValue += 0.5),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Пропустить"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(currentValue),
              child: const Text("Сохранить"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final previousState = controller.previousState;
    final nextStateAssumption = controller.nextStateAssumption;
    return BottomControlBar(
      backLabel: previousState?.prettyName ?? "(недоступно)",
      onTapBack: previousState != null ? () => _onTapBack(controller) : null,
      onTapNext: nextStateAssumption != null ? () => _onTapNext(context, controller) : null,
      nextLabel: nextStateAssumption?.prettyName ?? "(недоступно)",
    );
  }
}

class BottomControlBar extends StatelessWidget {
  final VoidCallback? onTapBack;
  final String backLabel;
  final VoidCallback? onTapNext;
  final String nextLabel;

  const BottomControlBar({
    super.key,
    this.onTapBack,
    this.backLabel = "Назад",
    this.onTapNext,
    this.nextLabel = "Далее",
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _GameControlButton(
                onTap: onTapBack,
                icon: Icons.arrow_back,
                label: backLabel,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _GameControlButton(
                onTap: onTapNext,
                icon: Icons.arrow_forward,
                label: nextLabel,
              ),
            ),
          ),
        ],
      );
}

class _GameControlButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;

  const _GameControlButton({
    this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? Theme.of(context).disabledColor : null;
    return ElevatedButton(
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color),
            Text(
              label,
              style: TextStyle(color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
