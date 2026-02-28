import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../services/database_service.dart';
import '../services/snackbar_service.dart';

class NoteProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  List<Note> _notes = [];
  bool _isLoading = false;

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;

  Future<void> loadNotes() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notes = await _db.getNotes();
    } catch (e) {
      debugPrint('Error loading notes: $e');
      SnackbarService.showError('Error al cargar notas');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addNote(Note note) async {
    try {
      final id = await _db.insertNote(note);
      final newNote = note.copyWith(id: id);
      _notes.insert(0, newNote); // Insert at top since descending
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding note: $e');
      SnackbarService.showError('Error al guardar la nota');
      rethrow; // Changed from `return null;` to `rethrow;` to match original signature
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      await _db.updateNote(note);
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = note;
        // Re-sort since updated_at changed
        _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating note: $e');
      SnackbarService.showError('Error al actualizar la nota');
      rethrow; // Changed from `return false;` to `rethrow;` to match original signature
    }
  }

  Future<void> deleteNote(int id) async {
    try {
      await _db.deleteNote(id);
      _notes.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting note: $e');
      SnackbarService.showError('Error al eliminar la nota');
      rethrow; // Changed from `return false;` to `rethrow;` to match original signature
    }
  }
}
