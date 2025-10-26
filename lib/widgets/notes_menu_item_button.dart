import "package:flutter/material.dart";

import "../screens/notes_screen.dart";
import "../utils/navigation.dart";

class NotesMenuItemButton extends StatelessWidget {
  const NotesMenuItemButton({super.key});

  @override
  Widget build(BuildContext context) => MenuItemButton(
        leadingIcon: const Icon(Icons.sticky_note_2, size: Checkbox.width),
        onPressed: () => openNotesPage(context),
        child: const Text("Заметки"),
      );
}
