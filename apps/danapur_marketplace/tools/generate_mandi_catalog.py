"""Regenerate the non-priced commodity seed from the editable catalogue."""
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
items = json.loads((ROOT / 'config/catalog/mandi_items.json').read_text())
ids = set()
rows = []
for item in items:
    if not re.fullmatch(r'[a-z][a-z0-9_-]{1,49}', item['id']) or item['id'] in ids:
        raise SystemExit('Invalid or duplicate commodity ID')
    if item['category'] not in ('Vegetables', 'Fruits') or item['default_unit'] not in ('kg', 'dozen', 'piece', 'bunch', '100 kg'):
        raise SystemExit('Invalid commodity category/unit')
    ids.add(item['id'])
    rows.append(' (' + ','.join("'" + item[key].replace("'", "''") + "'" for key in ('id', 'name', 'hindi_name', 'category', 'default_unit')) + ')')
output = '-- Common/seasonal commodities only. NO prices, shops or fictional listings.\n-- Existing administrator edits are preserved when rerun.\nbegin;\ninsert into public.mandi_items(id,name,hindi_name,category,default_unit) values\n' + ',\n'.join(rows) + '\non conflict(id) do nothing;\ncommit;\n'
seed = ROOT / 'supabase/seeds/001_mandi_items.sql'
if '--check' in sys.argv:
    if seed.read_text() != output:
        raise SystemExit('Catalogue seed is stale; run tools/generate_mandi_catalog.py and commit the result.')
else:
    seed.write_text(output)
print(f'Generated {len(items)} unpriced commodities.')
