import "dart:async";
import "dart:math";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../game/player.dart";
import "../utils/db/repo.dart";
import "../utils/errors.dart";
import "../utils/extensions.dart";
import "../utils/game_controller.dart";
import "../utils/navigation.dart";
import "../utils/ui.dart";
import "../widgets/confirm_pop_scope.dart";
import "../widgets/confirmation_dialog.dart";

enum _ValidationErrorType {
  tooMany,
  tooFew,
  missing,
}

class ChooseRolesScreen extends StatefulWidget {
  const ChooseRolesScreen({super.key});

  @override
  State<ChooseRolesScreen> createState() => _ChooseRolesScreenState();
}

class _ChooseRolesScreenState extends State<ChooseRolesScreen> {
  final _roles = List<Set<PlayerRole>>.generate(
    rolesList.length,
    (_) => PlayerRole.values.toSet(),
    growable: false,
  );
  final _errorsByRole = <PlayerRole, _ValidationErrorType>{};
  final _errorsByIndex = <int>{};
  final _chosenNicknames = List<String?>.generate(rolesList.length, (index) => null);
  final _chosenMemberIds = List<int?>.generate(rolesList.length, (index) => null);
  var _isModified = false;
  
  // Режим "Колода"
  var _isDeckMode = false;
  final _deckRoles = <PlayerRole>[];
  final _assignedRoles = List<PlayerRole?>.generate(rolesList.length, (index) => null);
  var _currentPlayerIndex = 0;

  @override
  void initState() {
    super.initState();
    final controller = context.read<GameController>();
    if (controller.isGameInitialized) {
      for (final (i, player) in controller.players.indexed) {
        _roles[i] = {player.role};
        _chosenNicknames[i] = player.nickname;
        _chosenMemberIds[i] = player.memberId;
      }
    }
  }

  void _changeValue(int index, PlayerRole role, bool value) {
    setState(() {
      if (value) {
        _roles[index].add(role);
      } else {
        _roles[index].remove(role);
      }
      _validate();
      _isModified = true;
    });
  }

  void _onNicknameSelected(int index, String? value) {
    setState(() {
      _isModified = true;
      _chosenNicknames[index] = value;
      
      // Найти соответствующий member_id для выбранного никнейма
      if (value != null) {
        final players = context.read<PlayerRepo>();
        if (players.data.isNotEmpty) {
          final player = players.data.firstWhere(
            (p) => p.$2.nickname == value,
            orElse: () => players.data.first,
          );
          _chosenMemberIds[index] = player.$2.memberId;
        }
      } else {
        _chosenMemberIds[index] = null;
      }
    });
  }

  /// Validates roles. Must be called from `setState` to update errors.
  void _validate() {
    final byRole = <PlayerRole, _ValidationErrorType>{};
    final byIndex = <int>{};

    // check if no roles are selected for player
    for (var i = 0; i < 10; i++) {
      if (_roles[i].isEmpty) {
        byIndex.add(i);
      }
    }

    // check if role is not chosen at least given amount of times
    final counter = <PlayerRole, int>{
      for (final role in PlayerRole.values) role: 0,
    };

    for (final rolesChoice in _roles) {
      if (rolesChoice.length == 1) {
        counter.update(rolesChoice.single, (value) => value + 1);
      }
    }
    for (final entry in counter.entries) {
      final requiredCount = roles[entry.key]!;
      if (entry.value > requiredCount) {
        byRole[entry.key] = _ValidationErrorType.tooMany;
      }
    }
    for (final rolesChoice in _roles) {
      if (rolesChoice.length <= 1) {
        continue;
      }
      for (final role in rolesChoice) {
        counter.update(role, (value) => value + 1);
      }
    }
    for (final entry in counter.entries) {
      final minimumCount = roles[entry.key]!;
      if (entry.value < minimumCount) {
        byRole[entry.key] =
            entry.value > 0 ? _ValidationErrorType.tooFew : _ValidationErrorType.missing;
      }
    }

    _errorsByRole
      ..clear()
      ..addAll(byRole);
    _errorsByIndex
      ..clear()
      ..addAll(byIndex);
  }

  List<PlayerRole>? _randomizeRoles() {
    final results = <List<PlayerRole>>[];
    final count = rolesList.length;
    for (var iDon = 0; iDon < count; iDon++) {
      if (!_roles[iDon].contains(PlayerRole.don)) {
        continue;
      }
      for (var iSheriff = 0; iSheriff < count; iSheriff++) {
        if (!_roles[iSheriff].contains(PlayerRole.sheriff) || iSheriff == iDon) {
          continue;
        }
        for (var iMafia = 0; iMafia < count; iMafia++) {
          if (!_roles[iMafia].contains(PlayerRole.mafia) || iMafia == iDon || iMafia == iSheriff) {
            continue;
          }
          for (var jMafia = iMafia + 1; jMafia < count; jMafia++) {
            if (!_roles[jMafia].contains(PlayerRole.mafia) ||
                jMafia == iDon ||
                jMafia == iSheriff) {
              continue;
            }
            var valid = true;
            for (var iCitizen = 0; iCitizen < count; iCitizen++) {
              if (iCitizen == iDon ||
                  iCitizen == iSheriff ||
                  iCitizen == iMafia ||
                  iCitizen == jMafia) {
                continue;
              }
              if (!_roles[iCitizen].contains(PlayerRole.citizen)) {
                valid = false;
                break;
              }
            }
            if (valid) {
              results.add([
                for (var i = 0; i < count; i++)
                  i == iDon
                      ? PlayerRole.don
                      : i == iSheriff
                          ? PlayerRole.sheriff
                          : i == iMafia || i == jMafia
                              ? PlayerRole.mafia
                              : PlayerRole.citizen,
              ]);
            }
          }
        }
      }
    }
    if (results.isEmpty) {
      return null;
    }
    final result = results.randomElement;
    assert(
      () {
        for (var i = 0; i < rolesList.length; i++) {
          if (!_roles[i].contains(result[i])) {
            return false;
          }
        }
        return true;
      }(),
      "Roles are invalid",
    );
    return result;
  }

  // Методы для режима "Колода"
  void _toggleDeckMode() {
    setState(() {
      _isDeckMode = !_isDeckMode;
      if (_isDeckMode) {
        _shuffleDeck();
        _currentPlayerIndex = 0;
        _assignedRoles.fillRange(0, _assignedRoles.length, null);
      }
      _isModified = true;
    });
  }

  void _shuffleDeck() {
    _deckRoles.clear();
    // Создаем колоду: 1 шериф, 1 дон, 2 мафии, 6 мирных жителей
    _deckRoles.addAll([
      PlayerRole.sheriff,
      PlayerRole.don,
      PlayerRole.mafia,
      PlayerRole.mafia,
      ...List.filled(6, PlayerRole.citizen),
    ]);
    _deckRoles.shuffle(Random());
  }

  void _onDeckRoleSelected(PlayerRole role) {
    if (_currentPlayerIndex >= rolesList.length) return;
    if (_chosenNicknames[_currentPlayerIndex] == null) {
      // Показываем сообщение, что нужно сначала выбрать игрока
      return;
    }
    
    setState(() {
      _assignedRoles[_currentPlayerIndex] = role;
      _deckRoles.remove(role);
      _currentPlayerIndex++;
      _isModified = true;
    });
  }

  String _getRoleDisplay(PlayerRole? role) {
    if (role == null) return "";
    return switch (role) {
      PlayerRole.sheriff => "Ш",
      PlayerRole.don => "Д", 
      PlayerRole.mafia => "М",
      PlayerRole.citizen => "",
    };
  }

  Widget _buildNormalMode(List<DropdownMenuEntry<String?>> nicknameEntries) {
    return SingleChildScrollView(
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: FlexColumnWidth(7),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(2),
          4: FlexColumnWidth(2),
        },
        children: [
          TableRow(
            children: [
              const Center(child: Text("Никнейм")),
              ...PlayerRole.values.map(
                (role) {
                  final errorText = _getErrorText(role);
                  return Tooltip(
                    message: errorText ?? "",
                    child: Center(
                      child: Text(
                        role.prettyName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: errorText != null ? Colors.red : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          for (var i = 0; i < 10; i++)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: DropdownMenu(
                    expandedInsets: EdgeInsets.zero,
                    enableFilter: true,
                    enableSearch: true,
                    label: Text("Игрок ${i + 1}"),
                    menuHeight: 256,
                    inputDecorationTheme: const InputDecorationTheme(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    errorText: _errorsByIndex.contains(i) ? "Роль не выбрана" : null,
                    requestFocusOnTap: true,
                    initialSelection: _chosenNicknames[i],
                    dropdownMenuEntries: nicknameEntries,
                    onSelected: (value) => _onNicknameSelected(i, value),
                  ),
                ),
                for (final role in PlayerRole.values)
                  Checkbox(
                    value: _roles[i].contains(role),
                    onChanged: (value) => _changeValue(i, role, value!),
                    isError: _errorsByRole.containsKey(role) || _errorsByIndex.contains(i),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDeckMode(PlayerRepo players) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Информация о текущем игроке
          if (_currentPlayerIndex < rolesList.length)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Игрок ${_currentPlayerIndex + 1}",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownMenu(
                      expandedInsets: EdgeInsets.zero,
                      enableFilter: true,
                      enableSearch: true,
                      label: const Text("Выберите игрока"),
                      menuHeight: 256,
                      inputDecorationTheme: const InputDecorationTheme(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      initialSelection: _chosenNicknames[_currentPlayerIndex],
                      dropdownMenuEntries: [
                        const DropdownMenuEntry(
                          value: null,
                          label: "",
                          labelWidget: Text("(*без никнейма*)", style: TextStyle(fontStyle: FontStyle.italic)),
                        ),
                        for (final nickname in players.data
                            .map((p) => p.$2.nickname)
                            .toList(growable: false)..sort())
                          DropdownMenuEntry(
                            value: nickname,
                            label: nickname,
                            enabled: !_chosenNicknames.contains(nickname) || _chosenNicknames[_currentPlayerIndex] == nickname,
                          ),
                      ],
                      onSelected: (value) => _onNicknameSelected(_currentPlayerIndex, value),
                    ),
                    const SizedBox(height: 8),
                    Text("Затем выберите роль из колоды:"),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Колода ролей
          Text(
            "Колода ролей (${_deckRoles.length} осталось):",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _deckRoles.asMap().entries.map((entry) {
              final index = entry.key;
              final role = entry.value;
              final isEnabled = _chosenNicknames[_currentPlayerIndex] != null;
              return GestureDetector(
                onTap: isEnabled ? () => _onDeckRoleSelected(role) : null,
                child: Card(
                  color: isEnabled 
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${index + 1}",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isEnabled ? null : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getRoleDisplay(role),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isEnabled ? null : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          role.prettyName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isEnabled ? null : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          // Список игроков с назначенными ролями
          Text(
            "Назначенные роли:",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          
          for (var i = 0; i < rolesList.length; i++)
            Card(
              color: i == _currentPlayerIndex 
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
              child: ListTile(
                title: Text("Игрок ${i + 1}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_chosenNicknames[i] != null)
                      Text("Игрок: ${_chosenNicknames[i]}"),
                    if (_assignedRoles[i] != null)
                      Text("Роль: ${_assignedRoles[i]!.prettyName}")
                    else if (_chosenNicknames[i] != null)
                      const Text("Роль не назначена")
                    else
                      const Text("Игрок не выбран"),
                  ],
                ),
                trailing: _assignedRoles[i] != null
                  ? Chip(
                      label: Text(_getRoleDisplay(_assignedRoles[i])),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    )
                  : null,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onFabPressed(BuildContext context) async {
    if (_isDeckMode) {
      // Проверяем, что все игроки выбраны
      final notSelectedPlayers = <int>[];
      for (var i = 0; i < rolesList.length; i++) {
        if (_chosenNicknames[i] == null) {
          notSelectedPlayers.add(i + 1);
        }
      }
      if (notSelectedPlayers.isNotEmpty) {
        showSnackBar(context, SnackBar(
          content: Text("Не выбраны игроки: ${notSelectedPlayers.join(", ")}"),
        ));
        return;
      }
      
      // Проверяем, что все роли назначены
      if (_deckRoles.isNotEmpty) {
        showSnackBar(context, const SnackBar(content: Text("Не все роли назначены игрокам")));
        return;
      }
      
      // Применяем роли из режима "Колода"
      final newRoles = _assignedRoles.cast<PlayerRole>();
      final showRoles = await showDialog<bool>(
        context: context,
        builder: (context) => const ConfirmationDialog(
          title: Text("Показать роли?"),
          content: Text("После применения ролей можно провести их раздачу игрокам"),
          rememberKey: "showRoles",
        ),
      );
      if (!context.mounted) {
        throw ContextNotMountedError();
      }
      if (showRoles == null) {
        return;
      }
      context.read<GameController>()
        ..roles = newRoles
        ..nicknames = _chosenNicknames
        ..memberIds = _chosenMemberIds
        ..startNewGame(rules: context.read());
      if (showRoles) {
        await openRolesPage(context);
        if (!context.mounted) {
          throw ContextNotMountedError();
        }
      }
      Navigator.pop(context);
      return;
    }
    
    // Обычный режим
    setState(_validate);
    if (_errorsByIndex.isNotEmpty || _errorsByRole.isNotEmpty) {
      showSnackBar(context, const SnackBar(content: Text("Для продолжения исправьте ошибки")));
      return;
    }
    final newRoles = _randomizeRoles();
    if (newRoles == null) {
      showSnackBar(
        context,
        const SnackBar(content: Text("Невозможно применить выбранные роли")),
      );
      return;
    }
    final showRoles = await showDialog<bool>(
      context: context,
      builder: (context) => const ConfirmationDialog(
        title: Text("Показать роли?"),
        content: Text("После применения ролей можно провести их раздачу игрокам"),
        rememberKey: "showRoles",
      ),
    );
    if (!context.mounted) {
      throw ContextNotMountedError();
    }
    if (showRoles == null) {
      return;
    }
    context.read<GameController>()
      ..roles = newRoles
      ..nicknames = _chosenNicknames
      ..memberIds = _chosenMemberIds
      ..startNewGame(rules: context.read());
    if (showRoles) {
      await openRolesPage(context);
      if (!context.mounted) {
        throw ContextNotMountedError();
      }
    }
    Navigator.pop(context);
  }

  void _toggleAll() {
    final anyChecked = _roles.any((rs) => rs.isNotEmpty);
    setState(() {
      _isModified = true;
      for (var i = 0; i < 10; i++) {
        if (anyChecked) {
          _roles[i].clear();
        } else {
          _roles[i] = PlayerRole.values.toSet();
        }
      }
      _validate();
    });
  }

  String? _getErrorText(PlayerRole role) => switch (_errorsByRole[role]) {
        _ValidationErrorType.tooMany => "Выбрана более ${roles[role]!} раз(-а)",
        _ValidationErrorType.tooFew => "Выбрана менее ${roles[role]!} раз(-а)",
        _ValidationErrorType.missing => "Роль не выбрана",
        null => null,
      };

  @override
  Widget build(BuildContext context) {
    final players = context.watch<PlayerRepo>();
    final nicknameEntries = [
      const DropdownMenuEntry(
        value: null,
        label: "",
        labelWidget: Text("(*без никнейма*)", style: TextStyle(fontStyle: FontStyle.italic)),
      ),
      for (final nickname in players.data
          .map((p) => p.$2.nickname)
          .toList(growable: false)..sort())
        DropdownMenuEntry(
          value: nickname,
          label: nickname,
          enabled: !_chosenNicknames.contains(nickname),
        ),
    ];
    return ConfirmPopScope(
      canPop: !_isModified,
      dialog: const ConfirmationDialog(
        title: Text("Отменить изменения"),
        content: Text("Вы уверены, что хотите отменить изменения?"),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isDeckMode ? "Колода ролей" : "Выбор ролей"),
          actions: [
            IconButton(
              tooltip: _isDeckMode ? "Перемешать колоду" : "Сбросить",
              onPressed: _isDeckMode ? _shuffleDeck : _toggleAll,
              icon: Icon(_isDeckMode ? Icons.shuffle : Icons.restart_alt),
            ),
            IconButton(
              tooltip: _isDeckMode ? "Обычный режим" : "Режим колоды",
              onPressed: _toggleDeckMode,
              icon: Icon(_isDeckMode ? Icons.list : Icons.style),
            ),
          ],
        ),
        body: _isDeckMode ? _buildDeckMode(players) : _buildNormalMode(nicknameEntries),
        floatingActionButton: FloatingActionButton(
          tooltip: "Применить",
          onPressed: () => _onFabPressed(context),
          child: const Icon(Icons.check),
        ),
      ),
    );
  }
}
