import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'data/knowledge_models.dart';
import 'data/knowledge_repository.dart';
import 'knowledge_scope.dart';
import 'knowledge_tokens.dart';
import 'markdown/markdown_renderer.dart';
import 'markdown/mention_field.dart';

/// Result handed back to the shell on Save / Publish.
class EditorResult {
  EditorResult(this.title, this.body, this.spaceId);
  final String title;
  final String body;
  final String spaceId;
}

/// Full markdown editor: title + space picker, formatting toolbar, and a split
/// markdown source ⇄ live preview that collapses to Write / Preview tabs below
/// ~760 px. Toolbar commands mirror the reference `linePrefix` / `surround` /
/// `insertBlock` helpers exactly.
class KnowledgeEditor extends StatefulWidget {
  const KnowledgeEditor({
    super.key,
    required this.isNew,
    required this.initialTitle,
    required this.initialBody,
    required this.spaceId,
    required this.onSave,
    required this.onCancel,
  });

  final bool isNew;
  final String initialTitle;
  final String initialBody;
  final String spaceId;
  final ValueChanged<EditorResult> onSave;
  final VoidCallback onCancel;

  @override
  State<KnowledgeEditor> createState() => _KnowledgeEditorState();
}

class _KnowledgeEditorState extends State<KnowledgeEditor> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initialTitle);
  late final TextEditingController _body =
      TextEditingController(text: widget.initialBody);
  final FocusNode _bodyFocus = FocusNode();
  late String _spaceId = widget.spaceId;
  String _tab = 'write'; // write | preview (narrow only)
  final List<TapGestureRecognizer> _recognizerSink = [];

  @override
  void initState() {
    super.initState();
    _body.addListener(_onBodyChanged);
  }

  void _onBodyChanged() => setState(() {});

  @override
  void dispose() {
    _body.removeListener(_onBodyChanged);
    for (final r in _recognizerSink) {
      r.dispose();
    }
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  // ── toolbar helpers (mirror the reference) ──
  void _surround(String before, String after, String placeholder) {
    final v = _body.value;
    final s = v.selection.start < 0 ? v.text.length : v.selection.start;
    final e = v.selection.end < 0 ? v.text.length : v.selection.end;
    final sel = e > s ? v.text.substring(s, e) : placeholder;
    final next = v.text.replaceRange(s, e, '$before$sel$after');
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection(
          baseOffset: s + before.length, extentOffset: s + before.length + sel.length),
    );
    _bodyFocus.requestFocus();
  }

  void _linePrefix(String prefix) {
    final v = _body.value;
    final s = v.selection.start < 0 ? v.text.length : v.selection.start;
    final e = v.selection.end < 0 ? v.text.length : v.selection.end;
    final lineStart = v.text.lastIndexOf('\n', s - 1) + 1;
    final block = v.text.substring(lineStart, e);
    final fixed = block
        .split('\n')
        .asMap()
        .entries
        .map((entry) => prefix.replaceFirst('%', '${entry.key + 1}') + entry.value)
        .join('\n');
    final next = v.text.replaceRange(lineStart, e, fixed);
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: lineStart + fixed.length),
    );
    _bodyFocus.requestFocus();
  }

  void _insertBlock(String text) {
    final v = _body.value;
    final s = v.selection.start < 0 ? v.text.length : v.selection.start;
    final pre = (s > 0 && v.text[s - 1] != '\n') ? '\n\n' : '';
    final next = v.text.replaceRange(s, s, '$pre$text');
    final caret = s + pre.length + text.length;
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caret),
    );
    _bodyFocus.requestFocus();
  }

  void _insertMention() {
    final v = _body.value;
    final s = v.selection.start < 0 ? v.text.length : v.selection.start;
    final next = v.text.replaceRange(s, s, '@');
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: s + 1),
    );
    _bodyFocus.requestFocus();
  }

  List<_Tool> get _tools => [
        _Tool('heading-1', 'Heading 1', () => _linePrefix('# ')),
        _Tool('heading-2', 'Heading 2', () => _linePrefix('## ')),
        _Tool('heading-3', 'Heading 3', () => _linePrefix('### ')),
        const _Tool.sep(),
        _Tool('bold', 'Bold', () => _surround('**', '**', 'bold')),
        _Tool('italic', 'Italic', () => _surround('*', '*', 'italic')),
        _Tool('strikethrough', 'Strikethrough', () => _surround('~~', '~~', 'strike')),
        _Tool('code', 'Inline code', () => _surround('`', '`', 'code')),
        const _Tool.sep(),
        _Tool('list', 'Bullet list', () => _linePrefix('- ')),
        _Tool('list-ordered', 'Numbered list', () => _linePrefix('%. ')),
        _Tool('list-checks', 'Task list', () => _linePrefix('- [ ] ')),
        _Tool('quote', 'Quote', () => _linePrefix('> ')),
        const _Tool.sep(),
        _Tool('link', 'Link', () => _surround('[', '](https://)', 'text')),
        _Tool('square-code', 'Code block', () => _insertBlock('```ts\n\n```')),
        _Tool('table', 'Table',
            () => _insertBlock('| Column | Column |\n| --- | --- |\n| Cell | Cell |')),
        _Tool('info', 'Info panel', () => _insertBlock(':::info\n\n:::')),
        _Tool('at-sign', 'Mention / link (@)', _insertMention),
      ];

  void _save() => widget.onSave(
      EditorResult(_title.text.trim(), _body.text, _spaceId));

  @override
  Widget build(BuildContext context) {
    final repo = KnowledgeScope.of(context).repo;
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= KbTokens.editorSplit;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(KbTokens.radiusCard),
            border: Border.all(color: AppColors.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _head(repo),
              _toolbar(split),
              Expanded(child: _body0(split, repo)),
            ],
          ),
        );
      },
    );
  }

  Widget _head(KnowledgeRepository repo) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 140, maxWidth: 380),
            child: TextField(
              controller: _title,
              autofocus: true,
              style: const TextStyle(
                  fontFamily: AppTheme.fontBrand,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: 'Article title…',
                hintStyle: TextStyle(color: AppColors.inkFaint),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(lucideIcon('hash'), size: 15, color: AppColors.inkFaint),
              const SizedBox(width: 6),
              DropdownButton<String>(
                value: _spaceId,
                underline: const SizedBox.shrink(),
                isDense: true,
                borderRadius: BorderRadius.circular(KbTokens.radiusControl),
                style: TextStyle(fontSize: 12.5, color: AppColors.ink),
                items: [
                  for (final s in repo.spaces)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _spaceId = v ?? _spaceId),
              ),
            ],
          ),
          TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: _save,
            icon: Icon(lucideIcon('check'), size: 16),
            label: Text(widget.isNew ? 'Publish' : 'Save'),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(bool split) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final t in _tools)
                  t.isSep
                      ? Container(
                          width: 1,
                          height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          color: AppColors.hairline,
                        )
                      : _ToolButton(tool: t),
              ],
            ),
          ),
          if (!split) _tabs(),
        ],
      ),
    );
  }

  Widget _tabs() {
    Widget tab(String id, String label) {
      final on = _tab == id;
      return GestureDetector(
        onTap: () => setState(() => _tab = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: on ? AppColors.surface : null,
            borderRadius: BorderRadius.circular(7),
            boxShadow: on
                ? [BoxShadow(color: AppColors.navyDeep.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: on ? AppColors.ink : AppColors.inkSoft)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.canvas2,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        tab('write', 'Write'),
        const SizedBox(width: 3),
        tab('preview', 'Preview'),
      ]),
    );
  }

  Widget _body0(bool split, KnowledgeRepository repo) {
    final showWrite = split || _tab == 'write';
    final showPreview = split || _tab == 'preview';
    if (split) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _writePane()),
          Container(width: 1, color: AppColors.hairline),
          Expanded(child: _previewPane()),
        ],
      );
    }
    return showWrite ? _writePane() : showPreview ? _previewPane() : const SizedBox();
  }

  Widget _writePane() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: MentionField(
        controller: _body,
        focusNode: _bodyFocus,
        expands: true,
        monospace: true,
        hintText: 'Write in markdown… type @ to link an issue, article or teammate.',
        onTabIndent: () {},
      ),
    );
  }

  Widget _previewPane() {
    // Dispose previous link recognizers before reparsing.
    for (final r in _recognizerSink) {
      r.dispose();
    }
    _recognizerSink.clear();
    final parser = KbMarkdownParser(sink: _recognizerSink);
    final parsed = parser.parse(_body.text);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_title.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(_title.text.trim(),
                  style: const TextStyle(
                      fontFamily: AppTheme.fontBrand,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6)),
            ),
          if (_body.text.trim().isEmpty)
            Text('Nothing to preview yet.',
                style: TextStyle(color: AppColors.inkFaint))
          else
            ...parsed.nodes,
        ],
      ),
    );
  }
}

class _Tool {
  const _Tool(this.icon, this.tooltip, this.action) : isSep = false;
  const _Tool.sep()
      : icon = '',
        tooltip = '',
        action = _noop,
        isSep = true;
  final String icon;
  final String tooltip;
  final VoidCallback action;
  final bool isSep;
  static void _noop() {}
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.tool});
  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tool.tooltip,
      child: InkWell(
        onTap: tool.action,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(lucideIcon(tool.icon), size: 17, color: AppColors.inkSoft),
        ),
      ),
    );
  }
}
