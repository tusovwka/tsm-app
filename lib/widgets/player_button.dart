import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../game/player.dart";
import "../utils/game_controller.dart";
import "../utils/ui.dart";

typedef ButtonTextBuilder = String Function(String text);

class BasicPlayerButton extends StatelessWidget {
  final int playerNumber;
  final bool isSelected;
  final bool isActive;
  final bool isAlive;
  final bool expanded;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ButtonTextBuilder? buttonTextBuilder;

  const BasicPlayerButton({
    super.key,
    required this.playerNumber,
    required this.isSelected,
    required this.isActive,
    required this.isAlive,
    this.expanded = false,
    this.onTap,
    this.onLongPress,
    this.buttonTextBuilder,
  });

  Color? _getBorderColor(BuildContext context) {
    if (isActive) {
      return Theme.of(context).colorScheme.primary;
    }
    if (isSelected) {
      return Colors.green;
    }
    return null;
  }

  Color? _getBackgroundColor() {
    if (!isAlive) {
      return Colors.red.withOpacity(0.25);
    }
    return null;
  }

  Color? _getForegroundColor() {
    if (isSelected) {
      return Colors.green;
    }
    if (!isAlive) {
      return Colors.white;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _getBorderColor(context);
    final text = expanded ? "Игрок #$playerNumber" : "$playerNumber";
    final builtText = buttonTextBuilder?.call(text);
    var fullText = expanded ? text : (builtText ?? text);
    if (expanded && builtText != null && builtText != "") {
      fullText += "\n$builtText";
    }
    return ElevatedButton(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        side: borderColor != null
            ? WidgetStateProperty.all(
                BorderSide(
                  color: borderColor,
                  width: 1,
                ),
              )
            : null,
        backgroundColor: WidgetStateProperty.all(_getBackgroundColor()),
        foregroundColor: WidgetStateProperty.all(_getForegroundColor()),
      ),
      onPressed: onTap,
      onLongPress: onLongPress,
      child: Center(
        child: Text(fullText, textAlign: TextAlign.center),
      ),
    );
  }
}

class PlayerButton extends StatelessWidget {
  final int playerNumber;
  final bool isSelected;
  final bool isActive;
  final bool showRole;
  final bool expanded;
  final VoidCallback? onTap;

  const PlayerButton({
    super.key,
    required this.playerNumber,
    required this.isSelected,
    this.isActive = false,
    this.showRole = false,
    this.expanded = false,
    this.onTap,
  });

  void _onLongPress(BuildContext context, GameController controller) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final controller = context.watch<GameController>();
        final player = controller.players.getByNumber(playerNumber);
        final isAliveText = player.state.isAlive
            ? "Жив"
            : player.state.isKicked
                ? "Удалён"
                : "Мёртв";
        return AlertDialog(
          title: Text(player.nicknameOrNumber),
          content: Text(
            "Номер игрока: ${player.number}\n"
            "Состояние: $isAliveText\n"
            // "Роль: ${player.role.prettyName}\n"
            "Фолов: ${player.state.warns}\n"
            "Жёлтых карточек: ${player.state.yellowCards}",
          ),
          actions: [
            MenuAnchor(
              menuChildren: [
                // Действия доступные только во время игры
                if (controller.isGameActive) ...[
                  MenuItemButton(
                    child: const Text("+ Фол"),
                    onPressed: () => controller.warnPlayer(playerNumber),
                  ),
                  MenuItemButton(
                    child: const Text("- Фол"),
                    onPressed: () => controller.warnMinusPlayer(playerNumber),
                  ),
                  MenuItemButton(
                    child: const Text("Дисквалификация"),
                    onPressed: () => controller.kickPlayer(playerNumber),
                  ),
                  MenuItemButton(
                    child: const Text("ППК"),
                    onPressed: () => controller.kickPlayerTeam(playerNumber),
                  ),
                ],
                // ЖК доступны всегда (и постфактум)
                MenuItemButton(
                  child: const Text("+ ЖК"),
                  onPressed: () => controller.addYellowCard(playerNumber),
                ),
                MenuItemButton(
                  child: const Text("- ЖК"),
                  onPressed: () => controller.removeYellowCard(playerNumber),
                ),
              ],
              builder: (context, menuController, _) => TextButton(
                onPressed: () {
                  if (menuController.isOpen) {
                    menuController.close();
                  } else {
                    menuController.open();
                  }
                },
                child: const Text("Действия"),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Закрыть"),
            ),
          ],
        );
      },
    );
  }

  String _getRoleSuffix(Player player, {bool full = false}) {
    if (!showRole) {
      return "";
    }
    if (full) {
      return player.role.prettyName;
    }
    switch (player.role) {
      case PlayerRole.mafia:
        return "М";
      case PlayerRole.don:
        return "Д";
      case PlayerRole.sheriff:
        return "Ш";
      case PlayerRole.citizen:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final player = controller.players.getByNumber(playerNumber);
    return Stack(
      children: [
        BasicPlayerButton(
          playerNumber: playerNumber,
          isSelected: isSelected,
          isActive: isActive,
          isAlive: player.state.isAlive,
          expanded: expanded,
          onTap: onTap,
          onLongPress: () => _onLongPress(context, controller),
          buttonTextBuilder: (text) {
            final nickname = player.nickname ?? "";
            final roleSuffix = _getRoleSuffix(player, full: expanded);
            if (!expanded) {
              return "$text$roleSuffix";
            }
            return "$nickname\n$roleSuffix".trim();
          },
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Text(
            player.state.isKicked ? "x" : "!" * player.state.warns,
            style: const TextStyle(color: Colors.red),
          ),
        ),
        // Желтые карточки
        if (player.state.yellowCards > 0)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: player.state.yellowCards >= 2 ? Colors.red : Colors.yellow,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: Center(
                child: Text(
                  "${player.state.yellowCards}",
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
