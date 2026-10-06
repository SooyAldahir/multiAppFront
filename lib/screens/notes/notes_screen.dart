import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import 'note_editor_screen.dart';

/// Notas personales en dos columnas, con búsqueda y notas fijadas arriba.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _notes = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  Timer? _debounce;
  late final DataRefresh _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = context.read<DataRefresh>()..addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _refresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final notes = await context.read<NotesRepository>().all(search: _search.trim());
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Error inesperado: $e';
        _loading = false;
      });
    }
  }

  void _onSearch(String value) {
    _search = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  void _open([Note? note]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notas')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.fab,
        foregroundColor: Colors.white,
        onPressed: _open,
        child: const Icon(Icons.edit_outlined),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          children: [
            TextField(
              onChanged: _onSearch,
              decoration: const InputDecoration(
                hintText: 'Buscar en tus notas',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.mutedLight),
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              ErrorState(message: _error!, onRetry: _load)
            else if (_notes.isEmpty)
              EmptyState(
                icon: Icons.sticky_note_2_outlined,
                title: _search.isEmpty ? 'Aún no tienes notas' : 'Sin resultados',
                message: _search.isEmpty ? 'Toca el lápiz para escribir tu primera nota.' : 'Prueba con otra palabra.',
              )
            else
              _TwoColumns(notes: _notes, onTap: _open),
          ],
        ),
      ),
    );
  }
}

class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.notes, required this.onTap});
  final List<Note> notes;
  final ValueChanged<Note> onTap;

  @override
  Widget build(BuildContext context) {
    final left = <Note>[];
    final right = <Note>[];
    for (var i = 0; i < notes.length; i++) {
      (i.isEven ? left : right).add(notes[i]);
    }
    Widget column(List<Note> items) => Column(
          children: [for (final n in items) _NoteCard(note: n, onTap: () => onTap(n))],
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(left)),
        const SizedBox(width: 10),
        Expanded(child: column(right)),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});
  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = ModuleTint.byName(note.color, fallback: ModuleTint.amber);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: tint.background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (note.isPinned) Icon(Icons.push_pin_rounded, size: 16, color: tint.foreground),
                  ],
                ),
                if ((note.content ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    note.content!,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF5E5C66), height: 1.35),
                  ),
                ],
                if (note.updatedAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    Fmt.shortDay(note.updatedAt!),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tint.foreground),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
