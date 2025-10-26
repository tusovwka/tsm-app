import "package:meta/meta.dart";

import "../utils/extensions.dart";

const roles = {
  PlayerRole.citizen: 6,
  PlayerRole.mafia: 2,
  PlayerRole.sheriff: 1,
  PlayerRole.don: 1,
};

final rolesList =
    roles.entries.expand((entry) => List.filled(entry.value, entry.key)).toUnmodifiableList();

enum RoleTeam {
  mafia,
  citizen,
  ;

  factory RoleTeam.byName(String name) => RoleTeam.values.byName(name);

  RoleTeam get other => switch (this) {
        RoleTeam.mafia => RoleTeam.citizen,
        RoleTeam.citizen => RoleTeam.mafia,
      };
}

enum PlayerRole {
  mafia(RoleTeam.mafia),
  don(RoleTeam.mafia),
  sheriff(RoleTeam.citizen),
  citizen(RoleTeam.citizen),
  ;

  /// The team this role belongs to.
  final RoleTeam team;

  const PlayerRole(this.team);

  factory PlayerRole.byName(String name) => PlayerRole.values.byName(name);
}

@immutable
class Player {
  final PlayerRole role;
  final int number;
  final String? nickname;
  final int? memberId;

  const Player({
    required this.role,
    required this.number,
    required this.nickname,
    this.memberId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          number == other.number &&
          nickname == other.nickname &&
          memberId == other.memberId;

  @override
  int get hashCode => Object.hash(role, number, nickname, memberId);

  @useResult
  PlayerWithState withState({
    PlayerState? state,
  }) =>
      PlayerWithState(
        role: role,
        number: number,
        nickname: nickname,
        memberId: memberId,
        state: state ?? const PlayerState(),
      );
}

@immutable
class PlayerState {
  final bool isAlive;
  final int warns;
  final bool isKicked;
  final int yellowCards;

  const PlayerState({
    this.isAlive = true,
    this.warns = 0,
    this.isKicked = false,
    this.yellowCards = 0,
  });

  @useResult
  PlayerState copyWith({
    bool? isAlive,
    int? warns,
    bool? isKicked,
    int? yellowCards,
  }) =>
      PlayerState(
        isAlive: isAlive ?? this.isAlive,
        warns: warns ?? this.warns,
        isKicked: isKicked ?? this.isKicked,
        yellowCards: yellowCards ?? this.yellowCards,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerState &&
          runtimeType == other.runtimeType &&
          isAlive == other.isAlive &&
          warns == other.warns &&
          isKicked == other.isKicked &&
          yellowCards == other.yellowCards;

  @override
  int get hashCode => Object.hash(isAlive, warns, isKicked, yellowCards);
}

@immutable
class PlayerWithState extends Player {
  final PlayerState state;

  const PlayerWithState({
    required super.role,
    required super.number,
    required super.nickname,
    super.memberId,
    required this.state,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerWithState &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          number == other.number &&
          nickname == other.nickname &&
          memberId == other.memberId &&
          state == other.state;

  @override
  int get hashCode => Object.hash(super.hashCode, state);
}

List<Player> generatePlayers({
  List<String?>? nicknames,
  List<PlayerRole>? roles,
  List<int?>? memberIds,
}) {
  final playerRoles = roles ?? (List.of(rolesList)..shuffle());
  return [
    for (var i = 0; i < playerRoles.length; i++)
      Player(
        role: playerRoles[i],
        number: i + 1,
        nickname: nicknames?.elementAt(i),
        memberId: memberIds?.elementAt(i),
      ),
  ].toUnmodifiableList();
}
