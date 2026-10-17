import 'package:flutter/material.dart';

/// Selected tags first (so they are always visible), then the rest, each group
/// sorted. A selected tag that is no longer offered (its category was
/// switched) still appears, so it can be unticked.
List<String> pinSelectedFirst(List<String> tags, Set<String> selected) {
  final pinned = selected.toList()..sort();
  final rest = tags.where((t) => !selected.contains(t)).toList()..sort();
  return [...pinned, ...rest];
}

/// Picker filter: case-insensitive substring match on the tag.
List<String> filterTags(List<String> tags, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return tags;
  return tags.where((t) => t.toLowerCase().contains(q)).toList();
}

const _chipText = TextStyle(fontSize: 11, fontWeight: FontWeight.w500);
const _chipTextSel = TextStyle(fontSize: 11, fontWeight: FontWeight.bold);
const _chipHPad = 10.0;
const _checkWidth = 12.0 + 4.0;
const _gap = 6.0;
const _linkText = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

/// New Order's tag filter: a single, non-scrolling row of chips that fits the
/// width, with a "More tags (N)" button opening [TagPickerDialog] for the rest.
/// [selected] is the screen's own set; it is mutated in place and [onChanged]
/// is called after every change.
class TagFilterRow extends StatelessWidget {
  final List<String> tags;
  final Set<String> selected;
  final VoidCallback onChanged;

  const TagFilterRow({
    super.key,
    required this.tags,
    required this.selected,
    required this.onChanged,
  });

  double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  double _chipWidth(BuildContext context, String tag, bool isSel) =>
      _textWidth(context, tag, isSel ? _chipTextSel : _chipText) +
      _chipHPad * 2 +
      2 + // border
      (isSel ? _checkWidth : 0);

  void _toggle(String tag) {
    if (!selected.remove(tag)) selected.add(tag);
    onChanged();
  }

  Future<void> _openPicker(BuildContext context, List<String> ordered) {
    return showDialog<void>(
      context: context,
      builder: (_) => TagPickerDialog(
        tags: ordered,
        selected: selected,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordered = pinSelectedFirst(tags, selected);
    return SizedBox(
      height: 32,
      child: LayoutBuilder(builder: (context, constraints) {
        // Leading icon + its gap.
        var available = constraints.maxWidth - 22;
        if (selected.isNotEmpty) {
          available -= _textWidth(
                  context, 'Clear (${selected.length})', _linkText) +
              12 +
              _gap;
        }

        // How many chips fit in [budget], in order.
        int fitting(double budget) {
          var used = 0.0;
          var n = 0;
          for (final tag in ordered) {
            final w = _chipWidth(context, tag, selected.contains(tag)) +
                (n == 0 ? 0 : _gap);
            if (used + w > budget) break;
            used += w;
            n++;
          }
          return n;
        }

        var shown = fitting(available);
        final needsMore = shown < ordered.length;
        if (needsMore) {
          // Reserve room for the widest label the button can have.
          final moreW = _textWidth(
                  context, 'More tags (${ordered.length})', _linkText) +
              16 + // icon
              4 +
              20 + // padding
              2 +
              _gap;
          shown = fitting(available - moreW);
        }
        final hidden = ordered.length - shown;

        return Row(
          children: [
            const Icon(Icons.tag_rounded, size: 16, color: Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            // The measurement above is close, not exact; clip rather than
            // ever reporting an overflow.
            Expanded(
              child: ClipRect(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    children: [
                      for (var i = 0; i < shown; i++) ...[
                        if (i > 0) const SizedBox(width: _gap),
                        _TagChip(
                          tag: ordered[i],
                          selected: selected.contains(ordered[i]),
                          onTap: () => _toggle(ordered[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (needsMore && hidden > 0) ...[
              const SizedBox(width: _gap),
              OutlinedButton.icon(
                key: const Key('moreTagsButton'),
                onPressed: () => _openPicker(context, ordered),
                icon: const Icon(Icons.expand_more_rounded, size: 16),
                label: Text('More tags ($hidden)', style: _linkText),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1D4ED8),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
            if (selected.isNotEmpty) ...[
              const SizedBox(width: _gap),
              InkWell(
                onTap: () {
                  selected.clear();
                  onChanged();
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'Clear (${selected.length})',
                    style: _linkText.copyWith(color: const Color(0xFFDC2626)),
                  ),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip(
      {required this.tag, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? const Color(0xFF1D4ED8) : const Color(0xFF475569);
    return Material(
      color: selected ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color:
                selected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: _chipHPad),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 12, color: fg),
                const SizedBox(width: 4),
              ],
              Text(tag,
                  maxLines: 1,
                  style: (selected ? _chipTextSel : _chipText)
                      .copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every tag with a checkbox, a search field, Clear and Done. Ticks apply
/// straight to [selected] (the same set the row uses), so closing the dialog
/// any way keeps them.
class TagPickerDialog extends StatefulWidget {
  final List<String> tags;
  final Set<String> selected;
  final VoidCallback onChanged;

  const TagPickerDialog({
    super.key,
    required this.tags,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<TagPickerDialog> {
  String _query = '';

  void _changed(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final visible = filterTags(widget.tags, _query);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filter by tags',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF141A24)),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.selected.length} selected · items with any of them show',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('tagPickerSearch'),
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.tags.length} tags',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF1EFEA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: visible.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No tags match.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8))),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final tag = visible[i];
                          return CheckboxListTile(
                            key: ValueKey('tagPick_$tag'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: widget.selected.contains(tag),
                            title: Text(tag,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                            onChanged: (v) => _changed(() {
                              if (v == true) {
                                widget.selected.add(tag);
                              } else {
                                widget.selected.remove(tag);
                              }
                            }),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: widget.selected.isEmpty
                        ? null
                        : () => _changed(widget.selected.clear),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626)),
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF182C4F)),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "+N" after the first tags an item row shows; hover (mouse) or tap shows
/// the full list.
class MoreTagsChip extends StatelessWidget {
  final List<String> tags;
  final int shown;
  final double fontSize;

  const MoreTagsChip({
    super.key,
    required this.tags,
    this.shown = 2,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tags.map((t) => '#$t').join('  '),
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 6),
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '+${tags.length - shown}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
