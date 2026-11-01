"""Create a local install ZIP only. No Steam/Git network calls or deployment."""
from pathlib import Path
import hashlib, json, zipfile

root=Path(__file__).resolve().parent.parent
meta=json.loads((root/'publishing/workshop.json').read_text(encoding='utf-8'))
source=root/'mods'
output=root/'releases';output.mkdir(exist_ok=True)
archive=output/('SuQingSprinklerFertilizer-'+meta['version']+'.zip')
files=sorted(p for p in source.rglob('*') if p.is_file())
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for p in files:z.write(p,p.relative_to(source).as_posix())
with zipfile.ZipFile(archive) as z:
    assert len(z.namelist())==len(files)
    for p in files:assert z.read(p.relative_to(source).as_posix())==p.read_bytes()
print(json.dumps({'archive':str(archive),'files':len(files),'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()},ensure_ascii=False))
