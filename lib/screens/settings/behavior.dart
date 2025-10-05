import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:vibration/vibration.dart";

import "../../utils/settings.dart";
import "../../utils/ui.dart";
import "../../widgets/list_tiles/choice.dart";
import "../../widgets/list_tiles/confirm.dart";

class BehaviorSettingsScreen extends StatefulWidget {
  const BehaviorSettingsScreen({super.key});

  @override
  State<BehaviorSettingsScreen> createState() => _BehaviorSettingsScreenState();
}

class _BehaviorSettingsScreenState extends State<BehaviorSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();

    return Scaffold(
      appBar: AppBar(title: const Text("Поведение")),
      body: ListView(
        children: [
          ChoiceListTile(
            leading: const Icon(Icons.timer),
            title: const Text("Режим таймера"),
            items: TimerType.values,
            itemToString: (item) => switch (item) {
              TimerType.shortened => "Сокращённый",
              TimerType.strict => "Строгий",
              TimerType.extended => "Увеличенный",
              TimerType.disabled => "Отключен",
            },
            index: settings.timerType.index,
            onChanged: settings.setTimerType,
          ),
        ],
      ),
    );
  }
}
