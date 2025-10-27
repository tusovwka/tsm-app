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
    controller.setNextState();
    onTapNext?.call();
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
