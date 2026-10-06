"""CSV/XLSX parsing for the Customers bulk-import feature.

Kept separate from views.py since it's a self-contained, independently
testable unit (file-format parsing + header-to-field guessing) rather than
request/response plumbing.
"""

import csv
import io
import re

try:
    import openpyxl
except ImportError:  # pragma: no cover - openpyxl is a hard requirement in prod
    openpyxl = None


# The only Customer fields an import can populate. `name`/`phone` are the
# only ones actually required by the model — everything else already has a
# blank/zero default, so an unmapped optional field just stays at that
# default rather than needing special-casing here.
TARGET_FIELDS = ['name', 'phone', 'email', 'address', 'area', 'notes']
REQUIRED_FIELDS = ['name', 'phone']

_ALIASES = {
    'name': ['name', 'customername', 'customer', 'fullname', 'clientname', 'client'],
    'phone': [
        'phone', 'mobile', 'contact', 'contactnumber', 'mobilenumber',
        'phonenumber', 'number', 'whatsapp', 'whatsappnumber',
    ],
    'email': ['email', 'emailaddress', 'mail'],
    'address': ['address', 'addr', 'location'],
    'area': ['area', 'locality', 'zone', 'neighbourhood', 'neighborhood'],
    'notes': ['notes', 'note', 'remarks', 'comment', 'comments'],
}


class ImportFileError(ValueError):
    """A user-facing problem with the uploaded file (bad format, empty, etc.)."""


def _normalize(header):
    return ''.join(ch for ch in header.lower() if ch.isalnum())


def guess_mapping(headers):
    """Best-effort {target_field: source_header} guess from column names.

    Presented to the user as a starting point for the mapping step, never
    applied blindly — they confirm or correct it before import runs.
    """
    normalized = [(h, _normalize(h)) for h in headers]
    mapping = {}
    for field, aliases in _ALIASES.items():
        for header, norm in normalized:
            if norm in aliases:
                mapping[field] = header
                break
    return mapping


def parse_rows(uploaded_file):
    """Returns (headers, rows) for a CSV or XLSX upload.

    `rows` is a list of lists of stripped strings, header row excluded,
    fully-blank rows skipped. XLSX detection is by filename extension; any
    other/missing extension is treated as CSV.
    """
    name = (getattr(uploaded_file, 'name', '') or '').lower()
    if name.endswith('.xlsx'):
        return _parse_xlsx(uploaded_file)
    return _parse_csv(uploaded_file)


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


def _cell_to_str(cell):
    """Stringifies one XLSX cell for import.

    A phone number typed as plain digits into a spreadsheet is stored as a
    *numeric* cell, not text — openpyxl hands it back as a Python float
    (e.g. `9876500001.0`), and a bare `str()` on that keeps the trailing
    `.0`, corrupting every imported number (and making it un-tappable as a
    phone link in the UI). Whole-number floats are rendered as plain
    integers instead; anything else (real decimals, text, dates) stringifies
    as normal.
    """
    if cell is None:
        return ''
    if isinstance(cell, float) and cell.is_integer():
        return str(int(cell))
    return str(cell)


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
        if not any(cell.strip() for cell in row):
            continue
        rows.append([cell.strip() for cell in row])
    return headers, rows


_TRAILING_ZERO_DECIMAL = re.compile(r'^(\d+)\.0+$')


def normalize_phone(value):
    """Strips a spurious `.0`/`.00` decimal tail from an imported phone number.

    A phone column stored (or CSV-exported) as a *numeric* cell round-trips
    as e.g. `9876500009.0` — the XLSX-parsing fix above catches this at the
    source for `.xlsx` uploads, but a CSV can carry the same corruption
    baked into its literal text if the source spreadsheet had the column
    Number-formatted. This is the last line of defense, applied to whatever
    the mapping resolves to for `phone` specifically, regardless of source
    format. Only strips an all-zero fractional part — a value with a real
    fraction isn't a phone number to begin with, so it's left alone rather
    than silently truncated.
    """
    value = (value or '').strip()
    match = _TRAILING_ZERO_DECIMAL.match(value)
    return match.group(1) if match else value


def rows_to_records(headers, rows, mapping):
    """Applies a {target_field: source_header} mapping to raw rows.

    Returns a list of {target_field: value} dicts. A row shorter than the
    mapped column's index yields '' for that field rather than raising.
    """
    index_by_header = {header: i for i, header in enumerate(headers)}
    records = []
    for row in rows:
        record = {}
        for field, header in mapping.items():
            idx = index_by_header.get(header)
            value = row[idx] if idx is not None and idx < len(row) else ''
            record[field] = value.strip() if isinstance(value, str) else value
        records.append(record)
    return records
