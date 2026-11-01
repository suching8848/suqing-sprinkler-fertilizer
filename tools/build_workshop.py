"""Prepare a local Workshop folder only; never deploy, upload or contact Steam."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import re
import struct


root = Path(__file__).resolve().parent.parent
publishing = root / 'publishing'
meta = json.loads((publishing / 'workshop.json').read_text(encoding='utf-8'))
mod_id = meta['mod_id']
version = meta['version']
if mod_id != 'SuQingSprinklerFertilizer' or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', version):
    raise ValueError('Unexpected Mod ID or unsafe version')
if meta.get('visibility') != 'private':
    raise ValueError('Local release preparation requires visibility=private')
if meta.get('preview') != 'publishing/preview.png':
    raise ValueError('Expected preview at publishing/preview.png')
if meta.get('required_workshop_ids') != ['3546314080']:
    raise ValueError('Expected Water Pipes as the sole required Workshop item')

output = root / 'releases' / 'Workshop' / (mod_id + '-' + version)
if output.exists():
    raise FileExistsError('Refusing to overwrite existing output: ' + str(output))

source = root / 'mods'
if {p.name for p in source.iterdir()} != {mod_id}:
    raise ValueError('Source mods must contain only the expected mod directory')
entries = sorted(source.rglob('*'))
if any(p.is_symlink() or getattr(p, 'is_junction', lambda: False)() for p in [source, *entries]):
    raise ValueError('Links and junctions are not allowed in the package source')
source_files = [p for p in entries if p.is_file()]
if not source_files:
    raise ValueError('No mod files found')
forbidden = {'.class', '.java', '.zip', '.bin', '.db', '.ini', '.log', '.partial'}
if any(p.suffix.lower() in forbidden for p in source_files):
    raise ValueError('Source includes development or personal-data file types')
contents = {p.relative_to(source).as_posix(): p.read_bytes() for p in source_files}

preview_path = publishing / 'preview.png'
preview = preview_path.read_bytes()
if (len(preview) < 33 or preview[:8] != b'\x89PNG\r\n\x1a\n'
        or preview[12:16] != b'IHDR' or struct.unpack('>II', preview[16:24]) != (512, 512)):
    raise ValueError('Workshop preview must be a 512 x 512 PNG')
if len(preview) >= 1_000_000:
    raise ValueError('Workshop preview must be smaller than 1 MB (1,000,000 bytes)')

title = meta['title']
tags = meta['tags']
if not isinstance(title, str) or any(c in title for c in '\r\n'):
    raise ValueError('Workshop title must be a single line')
if not isinstance(tags, list) or any(not isinstance(tag, str) or any(c in tag for c in ';\r\n') for tag in tags):
    raise ValueError('Workshop tags must be separate single-line strings')
lines = ['version=1']
workshop_id = meta.get('workshop_id')
if workshop_id is not None:
    if not re.fullmatch(r'[0-9]+', str(workshop_id)):
        raise ValueError('Workshop ID must be numeric or null')
    lines.append('id=' + str(workshop_id))
lines.append('title=' + title)
description = (publishing / 'description.bbcode.txt').read_text(encoding='utf-8')
lines.extend('description=' + line for line in description.splitlines())
lines.extend(['tags=' + ';'.join(tags), 'visibility=private'])
workshop_text = ('\n'.join(lines) + '\n').encode('utf-8')
changenote = (publishing / 'changenote.txt').read_bytes()

output.mkdir(parents=True, exist_ok=False)
output_files = {}
for relative, data in contents.items():
    destination = output / 'Contents' / 'mods' / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    output_files['Contents/mods/' + relative] = data
for relative, data in [('preview.png', preview), ('workshop.txt', workshop_text), ('changenote.txt', changenote)]:
    (output / relative).write_bytes(data)
    output_files[relative] = data

actual_files = {p.relative_to(output).as_posix() for p in output.rglob('*') if p.is_file()}
if actual_files != set(output_files):
    raise RuntimeError('Output file paths differ from the expected package')
for relative, data in output_files.items():
    if (output / relative).read_bytes() != data:
        raise RuntimeError('Output content verification failed: ' + relative)
for relative, data in contents.items():
    if (source / relative).read_bytes() != data:
        raise RuntimeError('Source changed during preparation: ' + relative)
if preview_path.read_bytes() != preview:
    raise RuntimeError('Preview changed during preparation')

sha256 = lambda data: hashlib.sha256(data).hexdigest()
manifest = {
    'created_at_utc': datetime.now(timezone.utc).isoformat(),
    'status': 'local_preparation_only_not_uploaded',
    'version': version,
    'mod_id': mod_id,
    'workshop_id': workshop_id,
    'required_workshop_ids': meta['required_workshop_ids'],
    'requirements_note': 'After the first upload, verify/add Water Pipes as an actual required Workshop item.',
    'source_mod_files': {str(Path('mods') / relative).replace('\\', '/'): {
        'bytes': len(data), 'sha256': sha256(data)} for relative, data in contents.items()},
    'source_preview': {'path': meta['preview'], 'bytes': len(preview), 'sha256': sha256(preview)},
    'output_files': {relative: {'bytes': len(data), 'sha256': sha256(data)}
                     for relative, data in output_files.items()},
}
manifest_path = output / 'manifest.json'
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
if json.loads(manifest_path.read_text(encoding='utf-8')) != manifest:
    raise RuntimeError('Manifest read-back verification failed')
print(json.dumps({'output': str(output), 'verified_mod_files': len(contents),
                  'manifest': str(manifest_path), 'uploaded': False}, ensure_ascii=False))
