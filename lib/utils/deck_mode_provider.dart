import "package:flutter/foundation.dart";

class DeckModeProvider with ChangeNotifier {
  bool _isDeckMode = true; // Дефолтно включен режим "Колода"
  
  bool get isDeckMode => _isDeckMode;
  
  void toggleDeckMode() {
    _isDeckMode = !_isDeckMode;
    notifyListeners();
  }
  
  void setDeckMode(bool value) {
    if (_isDeckMode != value) {
      _isDeckMode = value;
      notifyListeners();
    }
  }
}
