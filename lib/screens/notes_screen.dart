import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";

import "../utils/notes/note.dart";
import "../utils/ui.dart";

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _newNoteController = TextEditingController();
  final _editNoteController = TextEditingController();
  String? _editingNoteId;

  @override
  void dispose() {
    _newNoteController.dispose();
    _editNoteController.dispose();
    super.dispose();
  }

  void _addNote() {
    final content = _newNoteController.text.trim();
    if (content.isNotEmpty) {
      context.read<NotesRepository>().addNote(content);
      _newNoteController.clear();
    }
  }

  void _editNote(Note note) {
    setState(() {
      _editingNoteId = note.id;
      _editNoteController.text = note.content;
    });
  }

  void _saveEdit() {
    if (_editingNoteId != null) {
      final content = _editNoteController.text.trim();
      if (content.isNotEmpty) {
        context.read<NotesRepository>().updateNote(_editingNoteId!, content);
      }
      setState(() {
        _editingNoteId = null;
        _editNoteController.clear();
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _editingNoteId = null;
      _editNoteController.clear();
    });
  }

  void _deleteNote(Note note) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Удалить заметку?"),
        content: const Text("Вы уверены, что хотите удалить эту заметку?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Отмена"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
              context.read<NotesRepository>().deleteNote(note.id);
            },
            child: const Text("Удалить"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesRepo = context.watch<NotesRepository>();
    final notes = notesRepo.notes;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Заметки"),
        actions: [
          if (notes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: "Удалить все заметки",
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Удалить все заметки?"),
                    content: const Text("Вы уверены, что хотите удалить все заметки?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Отмена"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, true);
                          notesRepo.clearAllNotes();
                        },
                        child: const Text("Удалить все"),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Поле для новой заметки
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newNoteController,
                    decoration: const InputDecoration(
                      hintText: "Новая заметка...",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _addNote(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addNote,
                  icon: const Icon(Icons.add),
                  tooltip: "Добавить заметку",
                ),
              ],
            ),
          ),
          const Divider(),
          // Список заметок
          Expanded(
            child: notes.isEmpty
                ? const Center(
                    child: Text(
                      "Заметок пока нет",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final isEditing = _editingNoteId == note.id;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isEditing) ...[
                                TextField(
                                  controller: _editNoteController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    hintText: "Редактировать заметку...",
                                  ),
                                  maxLines: null,
                                  textCapitalization: TextCapitalization.sentences,
                                  autofocus: true,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: _cancelEdit,
                                      child: const Text("Отмена"),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _saveEdit,
                                      child: const Text("Сохранить"),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Text(
                                  note.content,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      DateFormat("dd.MM.yyyy HH:mm").format(note.updatedAt),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => _editNote(note),
                                      tooltip: "Редактировать",
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20),
                                      onPressed: () => _deleteNote(note),
                                      tooltip: "Удалить",
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
