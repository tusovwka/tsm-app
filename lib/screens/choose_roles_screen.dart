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
  final bool initialDeckMode;
  
  const ChooseRolesScreen({super.key, this.initialDeckMode = true});

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
  late var _isDeckMode;
  final _deckRoles = <PlayerRole>[];
  final _assignedRoles = List<PlayerRole?>.generate(rolesList.length, (index) => null);
  var _currentPlayerIndex = 0;

  @override
  void initState() {
    super.initState();
    _isDeckMode = widget.initialDeckMode;
    
    final controller = context.read<GameController>();
    if (controller.isGameInitialized) {
      for (final (i, player) in controller.players.indexed) {
        _roles[i] = {player.role};
        _chosenNicknames[i] = player.nickname;
        _chosenMemberIds[i] = player.memberId;
      }
    }
    
    // Инициализируем колоду при первом запуске
    if (_isDeckMode) {
      _shuffleDeck();
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
    setState(() {
      // Если колода пустая, создаем новую
      if (_deckRoles.isEmpty) {
      // Создаем колоду: 1 шериф, 1 дон, 2 мафии, 6 мирных жителей
      _deckRoles.addAll([
        PlayerRole.sheriff,
        PlayerRole.don,
        PlayerRole.mafia,
        PlayerRole.mafia,
        ...List.filled(6, PlayerRole.citizen),
      ]);
      // Сбрасываем назначенные роли и текущего игрока
      _assignedRoles.fillRange(0, _assignedRoles.length, null);
      _currentPlayerIndex = 0;
      }
      // Перемешиваем текущую колоду
      _deckRoles.shuffle(Random());
      _isModified = true;
    });
  }

  void _onDeckRoleSelected(PlayerRole role) {
    if (_currentPlayerIndex >= rolesList.length) return;
    
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

  String _getRoleDisplayForField(PlayerRole? role) {
    if (role == null) return "";
    return role.prettyName;
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
    return Row(
        children: [
        // Колонка с игроками
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 10; i++)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownMenu(
                    expandedInsets: EdgeInsets.zero,
                    enableFilter: true,
                    enableSearch: true,
                                menuHeight: 256,
                    label: Text("Игрок ${i + 1}"),
                                inputDecorationTheme: InputDecorationTheme(
                      isDense: true,
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: _currentPlayerIndex == i && _assignedRoles[i] == null
                                          ? Theme.of(context).colorScheme.primary
                                          : (_assignedRoles[i] != null
                                              ? Theme.of(context).colorScheme.secondaryContainer
                                              : Theme.of(context).colorScheme.outline),
                                      width: _currentPlayerIndex == i && _assignedRoles[i] == null ? 2 : 1,
                                    ),
                                  ),
                                  filled: _assignedRoles[i] != null || (_currentPlayerIndex == i && _assignedRoles[i] == null),
                                  fillColor: _assignedRoles[i] != null
                                      ? Theme.of(context).colorScheme.secondaryContainer
                                      : _currentPlayerIndex == i && _assignedRoles[i] == null
                                          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                                          : null,
                    ),
                    requestFocusOnTap: true,
                    initialSelection: _chosenNicknames[i],
                    dropdownMenuEntries: [
                      const DropdownMenuEntry(
                        value: null,
                        label: "",
                        labelWidget: Text("(Гость)", style: TextStyle(fontStyle: FontStyle.italic)),
                      ),
                      for (final nickname in players.data
                          .map((p) => p.$2.nickname)
                          .toList(growable: false)..sort())
                        DropdownMenuEntry(
                          value: nickname,
                          label: nickname,
                          enabled: !_chosenNicknames.contains(nickname) || _chosenNicknames[i] == nickname,
                        ),
                    ],
                    onSelected: (value) => _onNicknameSelected(i, value),
                  ),
                              if (_assignedRoles[i] != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 12, top: 4),
                                  child: Row(
                                    children: [
                                      Text(
                                        _getRoleDisplay(_assignedRoles[i]),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _getRoleDisplayForField(_assignedRoles[i]),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.secondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_assignedRoles[i] != null)
                          IconButton(
                            icon: Icon(Icons.close),
                            tooltip: "Убрать роль",
                            onPressed: () {
                              setState(() {
                                _deckRoles.add(_assignedRoles[i]!);
                                _deckRoles.shuffle(Random());
                                _assignedRoles[i] = null;
                                _isModified = true;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Вертикальная черта-разделитель
        VerticalDivider(width: 1),
        // Колонка с колодой ролей
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (MediaQuery.of(context).size.width >= 600)
                  Text(
                    "Колода ролей",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (MediaQuery.of(context).size.width >= 600)
                  const SizedBox(height: 16),
                for (var i = 0; i < _deckRoles.length; i++)
                  _buildDeckRoleCard(i, _deckRoles[i]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeckRoleCard(int index, PlayerRole role) {
    final isSelectable = _currentPlayerIndex < rolesList.length;
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSelectable ? () => _onDeckRoleSelected(role) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 16,
              vertical: isMobile ? 10 : 16,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelectable
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                width: 2,
              ),
              color: isSelectable
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Номер
                Container(
                  width: isMobile ? 24 : 32,
                  height: isMobile ? 24 : 32,
                  decoration: BoxDecoration(
                    color: isSelectable
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 12 : 14,
                        color: isSelectable
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 16),
                // Название роли (полное или сокращение)
                Expanded(
                  child: Text(
                    isMobile ? _getRoleDisplay(role) : role.prettyName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelectable
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Сокращение для ПК
                if (!isMobile)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      _getRoleDisplay(role),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelectable
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(int playerIndex, PlayerRole role) {
    final isAssigned = _assignedRoles[playerIndex] == role;
    final isCurrentPlayer = playerIndex == _currentPlayerIndex;
    final isInDeck = _deckRoles.contains(role);
    
    return GestureDetector(
      onTap: () {
        if (isAssigned) {
          // Убираем роль
          setState(() {
            _assignedRoles[playerIndex] = null;
            _deckRoles.add(role);
            _deckRoles.shuffle(Random());
            _isModified = true;
          });
        } else if (isInDeck && isCurrentPlayer) {
          // Назначаем роль
          _onDeckRoleSelected(role);
        }
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isAssigned 
              ? Theme.of(context).colorScheme.primary
              : isCurrentPlayer && isInDeck
                ? Theme.of(context).colorScheme.outline
                : Theme.of(context).colorScheme.surfaceVariant,
            width: 2,
          ),
          color: isAssigned 
            ? Theme.of(context).colorScheme.primaryContainer
            : isCurrentPlayer && isInDeck
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAssigned)
              Text(
                _getRoleDisplay(role),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              )
            else if (isCurrentPlayer && isInDeck)
              Text(
                "?",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              )
            else
              Text(
                "",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            Text(
              role.prettyName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isAssigned 
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : isCurrentPlayer && isInDeck
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onFabPressed(BuildContext context) async {
    if (_isDeckMode) {
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
