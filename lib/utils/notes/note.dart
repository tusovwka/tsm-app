import "package:flutter/foundation.dart";
import "package:hive/hive.dart";
import "package:meta/meta.dart";

import "../log.dart";

part "note.g.dart";

@HiveType(typeId: 3)
@immutable
class Note {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String content;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  @useResult
  Note copyWith({
    String? content,
    DateTime? updatedAt,
  }) =>
      Note(
        id: id,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          content == other.content &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, content, createdAt, updatedAt);
}

class NotesRepository with ChangeNotifier {
  static final _log = Logger("NotesRepository");
  
  final _box = Hive.box<Note>("notes");

  List<Note> get notes => _box.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> addNote(String content) async {
    if (content.trim().isEmpty) return;
    
    final note = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await _box.put(note.id, note);
    notifyListeners();
    _log.info("Added note: ${note.id}");
  }

  Future<void> updateNote(String id, String content) async {
    if (content.trim().isEmpty) return;
    
    final existingNote = _box.get(id);
    if (existingNote == null) return;
    
    final updatedNote = existingNote.copyWith(content: content.trim());
    await _box.put(id, updatedNote);
    notifyListeners();
    _log.info("Updated note: $id");
  }

  Future<void> deleteNote(String id) async {
    await _box.delete(id);
    notifyListeners();
    _log.info("Deleted note: $id");
  }

  Future<void> clearAllNotes() async {
    await _box.clear();
    notifyListeners();
    _log.info("Cleared all notes");
  }
}
