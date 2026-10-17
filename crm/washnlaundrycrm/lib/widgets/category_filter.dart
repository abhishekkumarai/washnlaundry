import 'package:flutter/material.dart';

import 'tag_filter.dart' show filterTags;

/// "All" ('') first, then the selected category, then the rest in their own
/// (display) order — so the current choice is always on screen.
List<String> pinSelectedCategory(List<String> categories, String selected) => [
      '',
      if (selected.isNotEmpty) selected,
      ...categories.where((c) => c != selected),
    ];

const _labelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
const _labelStyleSel = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);

/// On the theme's label font, as the Material chips this row replaced were.
TextStyle _themed(BuildContext context, TextStyle style) =>
    (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).merge(style);
const _chipHPad = 14.0;
const _gap = 8.0;
const _maxLabelWidth = 160.0;
const _moreText = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

/// New Order's service-category filter: one non-scrolling row of chips that
/// fits the width, "All" and the selected category pinned first, and a
/// "More services (N)" button opening [CategoryPickerDialog] for the rest.
/// Single choice; '' means All.
class CategoryFilterRow extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const CategoryFilterRow({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _themed(context, style)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  static String _label(String value) => value.isEmpty ? 'All' : value;

  double _labelWidth(BuildContext context, String value) => _textWidth(
      context, _label(value), value == selected ? _labelStyleSel : _labelStyle);

  @override
  Widget build(BuildContext context) {
    final ordered = pinSelectedCategory(categories, selected);
    return SizedBox(
      height: 38,
      child: LayoutBuilder(builder: (context, constraints) {
        final available = constraints.maxWidth;

        int fitting(double budget, double labelCap) {
          var used = 0.0;
          var n = 0;
          for (final value in ordered) {
            final w =
                _labelWidth(context, value).clamp(0, labelCap) +
                    _chipHPad * 2 +
                    2 +
                    (n == 0 ? 0 : _gap);
            if (used + w > budget) break;
            used += w;
            n++;
          }
          return n;
        }

        var labelCap = _maxLabelWidth;
        var shown = fitting(available, labelCap);
        final needsMore = shown < ordered.length;
        var shortMore = false;
        if (needsMore) {
          // Reserve room for the widest label the button can have; on a row
          // too narrow for that plus one service, use the short "More (N)".
          double moreWidth(String prefix) =>
              _textWidth(context, '$prefix (${ordered.length})', _moreText) +
              16 + // icon
              4 +
              24 + // padding
              2 +
              _gap;
          final allW = _labelWidth(context, '') + _chipHPad * 2 + 2 + _gap;
          const minChip = 40.0 + _chipHPad * 2 + 2;
          shortMore = available - moreWidth('More services') - allW < minChip;
          final budget =
              available - moreWidth(shortMore ? 'More' : 'More services');
          // Narrow row: shrink the cap so All and the selected category still
          // fit beside the button.
          labelCap = (budget - allW - _chipHPad * 2 - 2)
              .clamp(40.0, _maxLabelWidth);
          shown = fitting(budget, labelCap);
        }
        final hidden = ordered.length - shown;

        return Row(
          children: [
            // The measurement is close, not exact; clip rather than ever
            // report an overflow.
            Expanded(
              child: ClipRect(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    children: [
                      for (var i = 0; i < shown; i++) ...[
                        if (i > 0) const SizedBox(width: _gap),
                        _CategoryChip(
                          label: _label(ordered[i]),
                          selected: ordered[i] == selected,
                          labelCap: labelCap,
                          truncated:
                              _labelWidth(context, ordered[i]) > labelCap,
                          onTap: () => onSelected(ordered[i]),
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
                key: const Key('moreCategoriesButton'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => CategoryPickerDialog(
                    categories: categories,
                    selected: selected,
                    onSelected: onSelected,
                  ),
                ),
                icon: const Icon(Icons.expand_more_rounded, size: 16),
                label: Text(
                    shortMore ? 'More ($hidden)' : 'More services ($hidden)',
                    style: _themed(context, _moreText)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF182C4F),
                  side: const BorderSide(color: Color(0xFFE4E0D8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final double labelCap;
  final bool truncated;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.labelCap,
    required this.truncated,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Material(
      color: selected ? const Color(0xFF182C4F) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color:
                selected ? const Color(0xFF182C4F) : const Color(0xFFE4E0D8)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: _chipHPad),
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: labelCap),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _themed(
                  context,
                  (selected ? _labelStyleSel : _labelStyle).copyWith(
                      color: selected
                          ? Colors.white
                          : const Color(0xFF334155))),
            ),
          ),
        ),
      ),
    );
    return truncated ? Tooltip(message: label, child: chip) : chip;
  }
}

/// Every category (plus All) with a search field; tapping one selects it and
/// closes the dialog.
class CategoryPickerDialog extends StatefulWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const CategoryPickerDialog({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<CategoryPickerDialog> createState() => _CategoryPickerDialogState();
}

class _CategoryPickerDialogState extends State<CategoryPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = [
      if (_query.trim().isEmpty) '',
      ...filterTags(widget.categories, _query),
    ];
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
              const Text(
                'Choose a service',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF141A24)),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('categoryPickerSearch'),
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.categories.length} services',
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
                        child: Text('No services match.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8))),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final value = visible[i];
                          final isSel = value == widget.selected;
                          return ListTile(
                            key: ValueKey('categoryPick_$value'),
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            title: Text(
                              value.isEmpty ? 'All' : value,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    isSel ? FontWeight.bold : FontWeight.w500,
                                color: const Color(0xFF141A24),
                              ),
                            ),
                            trailing: isSel
                                ? const Icon(Icons.check_rounded,
                                    size: 18, color: Color(0xFF182C4F))
                                : null,
                            onTap: () {
                              widget.onSelected(value);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
