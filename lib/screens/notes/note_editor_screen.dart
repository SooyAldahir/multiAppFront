import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../agenda/event_form_screen.dart' show ColorPicker;

/// Crear o editar una nota.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.note});
  final Note? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _title = TextEditingController(text: widget.note?.title);
  late final TextEditingController _content = TextEditingController(text: widget.note?.content);
  late bool _pinned = widget.note?.isPinned ?? false;
  late String _color = widget.note?.color ?? 'amber';
  bool _saving = false;

  bool get _isEditing => widget.note?.id != null;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim().isEmpty
        ? (_content.text.trim().split('\n').first.trim())
        : _title.text.trim();
    if (title.isEmpty) {
      showMessage(context, 'Escribe un título o algo de contenido', error: true);
      return;
    }
    final note = Note(
      title: title.length > 150 ? title.substring(0, 150) : title,
      content: _content.text,
      color: _color,
      isPinned: _pinned,
    );

    setState(() => _saving = true);
    final repo = context.read<NotesRepository>();
    final refresh = context.read<DataRefresh>();
    try {
      if (_isEditing) {
        await repo.update(widget.note!.id!, note.toJson());
      } else {
        await repo.create(note);
      }
      refresh.changed();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(context, title: 'Eliminar nota', message: 'Esta acción no se puede deshacer.');
    if (!ok || !mounted) return;
    final repo = context.read<NotesRepository>();
    final refresh = context.read<DataRefresh>();
    try {
      await repo.delete(widget.note!.id!);
      refresh.changed();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _chooseColor() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Color de la nota', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              ColorPicker(
                selected: _color,
                onChanged: (c) {
                  setState(() => _color = c);
                  setSheet(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tint = ModuleTint.byName(_color, fallback: ModuleTint.amber);
    return Scaffold(
      backgroundColor: Color.lerp(AppColors.background, tint.background, 0.6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: _pinned ? 'Desfijar' : 'Fijar',
            onPressed: () => setState(() => _pinned = !_pinned),
            icon: Icon(_pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: _pinned ? tint.foreground : null),
          ),
          IconButton(tooltip: 'Color', onPressed: _chooseColor, icon: const Icon(Icons.palette_outlined)),
          if (_isEditing)
            IconButton(tooltip: 'Eliminar', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        children: [
          TextField(
            controller: _title,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            decoration: const InputDecoration(
              hintText: 'Título',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _content,
            maxLines: null,
            minLines: 12,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 16, height: 1.5),
            decoration: const InputDecoration(
              hintText: 'Escribe aquí…',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
