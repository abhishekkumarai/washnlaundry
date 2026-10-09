"""CSV and JSON parsing/generation for Services & Garment Items import/export.

Provides:
- export_services_csv(category_ids=None) -> str: CSV text with service items
- export_services_json(category_ids=None) -> list[dict]: structured JSON catalog
- parse_services_rows(uploaded_file) -> (headers, rows) for CSV or XLSX
- import_services_commit(records, overwrite_duplicates=True) -> dict: execution summary
- guess_services_mapping(headers) -> dict: mapping suggestions
"""

import csv
import io
import re

try:
    import openpyxl
except ImportError:  # pragma: no cover
    openpyxl = None

from .models import GarmentCategory, GarmentItem, PricingUnit


TARGET_FIELDS = [
    'category',
    'name',
    'price',
    'unit',
    'icon',
    'image_url',
    'is_active',
    'display_order',
    'category_icon',
]

REQUIRED_FIELDS = ['category', 'name', 'price']

_ALIASES = {
    'category': ['category', 'categoryname', 'service', 'servicename', 'section', 'department'],
    'name': ['name', 'item', 'itemname', 'garment', 'garmentname', 'product', 'productname'],
    'price': ['price', 'rate', 'cost', 'unitprice', 'itemprice', 'amount'],
    'unit': ['unit', 'pricingunit', 'uom', 'type'],
    'icon': ['icon', 'itemicon', 'garmenticon'],
    'image_url': ['image', 'imageurl', 'photo', 'picture'],
    'is_active': ['active', 'isactive', 'status', 'enabled'],
    'display_order': ['order', 'displayorder', 'sortorder', 'sequence'],
    'category_icon': ['categoryicon', 'serviceicon'],
}

_UNIT_LOOKUP = {
    'pc': PricingUnit.PIECE,
    'piece': PricingUnit.PIECE,
    'per pc': PricingUnit.PIECE,
    'per piece': PricingUnit.PIECE,
    'kg': PricingUnit.KG,
    'per kg': PricingUnit.KG,
    'sqft': PricingUnit.SQFT,
    'sq.ft': PricingUnit.SQFT,
    'sq ft': PricingUnit.SQFT,
    'per sqft': PricingUnit.SQFT,
    'per sq.ft': PricingUnit.SQFT,
    'set': PricingUnit.SET,
    'per set': PricingUnit.SET,
}


class ImportFileError(ValueError):
    """User-facing error when uploaded file cannot be parsed."""


def _normalize(header):
    return ''.join(ch for ch in str(header).lower() if ch.isalnum())


def guess_services_mapping(headers):
    """Best-effort {target_field: source_header} mapping from column headers."""
    normalized = [(h, _normalize(h)) for h in headers]
    mapping = {}
    for field, aliases in _ALIASES.items():
        for header, norm in normalized:
            if norm in aliases:
                mapping[field] = header
                break
    return mapping


def _cell_to_str(cell):
    if cell is None:
        return ''
    if isinstance(cell, float) and cell.is_integer():
        return str(int(cell))
    return str(cell)


def _parse_xlsx(uploaded_file):
    if openpyxl is None:  # pragma: no cover
        raise ImportFileError('XLSX support is not available on the server.')
    try:
        workbook = openpyxl.load_workbook(uploaded_file, read_only=True, data_only=True)
    except Exception as exc:
        raise ImportFileError(f'Could not read the XLSX file: {exc}') from exc

    sheet = workbook.active
    rows_iter = sheet.iter_rows(values_only=True)
    try:
        header_row = next(rows_iter)
    except StopIteration:
        return [], []
    headers = [_cell_to_str(cell).strip() for cell in header_row]

    rows = []
    for row in rows_iter:
        if all(_cell_to_str(cell).strip() == '' for cell in row):
            continue
        rows.append([_cell_to_str(cell).strip() for cell in row])
    return headers, rows


def _parse_csv(uploaded_file):
    raw = uploaded_file.read()
    try:
        text = raw.decode('utf-8-sig')
    except UnicodeDecodeError as exc:
        raise ImportFileError(f'Could not read the file as text: {exc}') from exc

    reader = csv.reader(io.StringIO(text))
    try:
        headers = [h.strip() for h in next(reader)]
    except StopIteration:
        return [], []

    rows = []
    for row in reader:
        if not any(str(cell).strip() for cell in row):
            continue
        rows.append([str(cell).strip() for cell in row])
    return headers, rows


def parse_services_rows(uploaded_file):
    """Parses CSV or XLSX into (headers, rows)."""
    name = (getattr(uploaded_file, 'name', '') or '').lower()
    if name.endswith('.xlsx'):
        return _parse_xlsx(uploaded_file)
    return _parse_csv(uploaded_file)


def rows_to_records(headers, rows, mapping):
    """Applies {target_field: source_header} mapping to rows."""
    index_by_header = {header: i for i, header in enumerate(headers)}
    records = []
    for row in rows:
        record = {}
        for field, header in mapping.items():
            idx = index_by_header.get(header)
            val = row[idx] if idx is not None and idx < len(row) else ''
            record[field] = val.strip() if isinstance(val, str) else str(val).strip()
        records.append(record)
    return records


def normalize_pricing_unit(raw_unit):
    if not raw_unit:
        return PricingUnit.PIECE
    clean = str(raw_unit).strip().lower()
    return _UNIT_LOOKUP.get(clean, PricingUnit.PIECE)


def parse_bool(value, default=True):
    if value is None or value == '':
        return default
    val_str = str(value).strip().lower()
    if val_str in ('false', '0', 'no', 'inactive', 'off'):
        return False
    if val_str in ('true', '1', 'yes', 'active', 'on'):
        return True
    return default


def parse_float(value, default=0.0):
    if value is None or value == '':
        return default
    try:
        # Strip currency symbols if present (₹, $, commas)
        cleaned = re.sub(r'[^\d.-]', '', str(value))
        return float(cleaned)
    except (ValueError, TypeError):
        return default


def parse_int(value, default=0):
    if value is None or value == '':
        return default
    try:
        return int(float(str(value).strip()))
    except (ValueError, TypeError):
        return default


def export_services_csv(category_ids=None):
    """Generates a CSV string of all (or selected) services/garment items."""
    qs = GarmentItem.objects.select_related('category').all().order_by(
        'category__display_order', 'display_order', 'id'
    )
    if category_ids:
        qs = qs.filter(category_id__in=category_ids)

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        'Category',
        'Category Icon',
        'Item Name',
        'Price',
        'Unit',
        'Item Icon',
        'Image URL',
        'Is Active',
        'Display Order',
    ])

    for item in qs:
        writer.writerow([
            item.category.name,
            item.category.icon,
            item.name,
            f"{item.price:.2f}",
            item.get_unit_display(),
            item.icon,
            item.image_url,
            'Yes' if item.is_active else 'No',
            item.display_order,
        ])

    return output.getvalue()


def export_services_json(category_ids=None):
    """Returns structured JSON/list of categories with nested items."""
    cat_qs = GarmentCategory.objects.prefetch_related('items').all().order_by(
        'display_order', 'id'
    )
    if category_ids:
        cat_qs = cat_qs.filter(id__in=category_ids)

    data = []
    for cat in cat_qs:
        items = []
        for item in cat.items.all().order_by('display_order', 'id'):
            items.append({
                'id': item.id,
                'name': item.name,
                'price': item.price,
                'unit': item.unit,
                'unit_label': item.get_unit_display(),
                'icon': item.icon,
                'image_url': item.image_url,
                'is_active': item.is_active,
                'display_order': item.display_order,
            })
        data.append({
            'id': cat.id,
            'name': cat.name,
            'icon': cat.icon,
            'display_order': cat.display_order,
            'is_active': cat.is_active,
            'items': items,
        })
    return data


def import_services_commit(records, overwrite_duplicates=True):
    """Processes mapped records and creates/updates categories and garment items.

    Returns:
    {
        'total_rows': int,
        'categories_created': int,
        'items_created': int,
        'items_updated': int,
        'skipped_missing': int,
        'skipped_duplicate': int,
    }
    """
    existing_categories = {c.name.strip().lower(): c for c in GarmentCategory.objects.all()}
    existing_items = {
        (item.category_id, item.name.strip().lower()): item
        for item in GarmentItem.objects.select_related('category').all()
    }

    categories_created = 0
    items_created = 0
    items_updated = 0
    skipped_missing = 0
    skipped_duplicate = 0

    to_create_items = []
    to_update_items = []

    for record in records:
        category_name = (record.get('category') or '').strip()
        item_name = (record.get('name') or '').strip()
        raw_price = record.get('price')

        if not category_name or not item_name or raw_price is None or raw_price == '':
            skipped_missing += 1
            continue

        price = parse_float(raw_price)
        unit = normalize_pricing_unit(record.get('unit'))
        icon = (record.get('icon') or '').strip() or 'Shirt'
        image_url = (record.get('image_url') or '').strip()
        is_active = parse_bool(record.get('is_active'), default=True)
        display_order = parse_int(record.get('display_order'), default=0)
        category_icon = (record.get('category_icon') or '').strip() or 'Shirt'

        # Find or create Category
        cat_key = category_name.lower()
        cat = existing_categories.get(cat_key)
        if not cat:
            cat = GarmentCategory.objects.create(
                name=category_name,
                icon=category_icon,
                display_order=len(existing_categories) + 1,
                is_active=True,
            )
            existing_categories[cat_key] = cat
            categories_created += 1

        # Check existing item under this category
        item_key = (cat.id, item_name.lower())
        existing = existing_items.get(item_key)

        if existing:
            if not overwrite_duplicates:
                skipped_duplicate += 1
                continue
            # Update existing
            existing.price = price
            existing.unit = unit
            if icon:
                existing.icon = icon
            if image_url != '':
                existing.image_url = image_url
            existing.is_active = is_active
            if display_order != 0:
                existing.display_order = display_order
            to_update_items.append(existing)
            items_updated += 1
        else:
            new_item = GarmentItem(
                category=cat,
                name=item_name,
                price=price,
                unit=unit,
                icon=icon,
                image_url=image_url,
                is_active=is_active,
                display_order=display_order or (cat.items.count() + len(to_create_items) + 1),
            )
            to_create_items.append(new_item)
            # Store in existing_items in case duplicate occurs within same file
            existing_items[item_key] = new_item
            items_created += 1

    if to_create_items:
        GarmentItem.objects.bulk_create(to_create_items)
    if to_update_items:
        GarmentItem.objects.bulk_update(
            to_update_items,
            ['price', 'unit', 'icon', 'image_url', 'is_active', 'display_order']
        )

    return {
        'total_rows': len(records),
        'categories_created': categories_created,
        'items_created': items_created,
        'items_updated': items_updated,
        'skipped_missing': skipped_missing,
        'skipped_duplicate': skipped_duplicate,
    }
