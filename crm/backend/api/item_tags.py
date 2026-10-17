"""Starter tags for catalogue items and categories (the New Order page's tag chips).

Used by both catalogues: `seed_db.py` (demo shops, Demo Mode) and
`default_services.py` (every newly provisioned shop), and by the `fill_item_tags`
command for items that have none. Every item gets at least one tag. Owners can edit
tags afterwards; nothing here overwrites tags that are already set.
"""
import re

# Category name keyword -> tag the whole category carries.
_CATEGORY_RULES = [
    ('shoes', ('shoe',)),
    ('home', ('household', 'furnishing')),
    ('premium', ('premium',)),
]

# Item name keyword -> tag. Matched as whole words (plural allowed), so "suit"
# does not match "suitcase" and "pant" does not match "pantry".
_ITEM_RULES = [
    ('male', ('shirt', 'kurta', 'sherwani', 'suit', 'blazer', 'trouser', 'pant', 'jeans',
              'shorts', 'overcoat', 'polo')),
    ('female', ('saree', 'lehenga', 'blouse', 'dupatta', 'salwar', 'top', 'kurti', 'dress',
                'gown', 'frock', 'skirt', 'legging', 'heel', 'kameez')),
    ('kids', ('frock', 'school uniform', 'soft toy', 'stroller', 'pram')),
    ('home', ('bedsheet', 'bedshoot', 'bedspread', 'pillow', 'blanket', 'comforter', 'quilt',
              'curtain', 'linen', 'household', 'carpet', 'sofa', 'towel')),
    ('winter', ('jacket', 'coat', 'overcoat', 'sweater', 'blanket', 'comforter', 'quilt')),
    ('shoes', ('shoe', 'sneaker', 'boot', 'sandal', 'footwear')),
    ('bags', ('bag', 'handbag', 'suitcase')),
]

# An item that matches nothing above still gets a tag, so every row has a chip.
FALLBACK_TAG = 'everyday'


def _has_word(text, word):
    return re.search(r'\b' + re.escape(word) + r's?\b', text) is not None


def category_tags(category_name):
    lowered = (category_name or '').lower()
    return [tag for tag, words in _CATEGORY_RULES if any(w in lowered for w in words)]


def item_tags(category_name, item_name, unit=None):
    """Tags for one catalogue item: its category's tags plus keyword matches, then
    'bulk' for anything priced per kg, and a fallback so the list is never empty."""
    lowered = (item_name or '').lower()
    tags = category_tags(category_name)
    for tag, words in _ITEM_RULES:
        if tag not in tags and any(_has_word(lowered, w) for w in words):
            tags.append(tag)
    if (str(unit or '').upper() == 'KG' or 'per kg' in lowered) and 'bulk' not in tags:
        tags.append('bulk')
    return tags or [FALLBACK_TAG]
