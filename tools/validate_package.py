"""Validate package metadata, option bounds and cross-language keys/placeholders."""
from pathlib import Path
import json, re, struct

root = Path(__file__).resolve().parent.parent
mod = root/'mods/SuQingSprinklerFertilizer'
media = mod/'42/media'
translations = media/'lua/shared/Translate'
files = sorted((translations/'EN').glob('*.json'))
for source in files:
    reference = json.loads(source.read_text(encoding='utf-8'))
    for lang in ('CN','CH'):
        data = json.loads((translations/lang/source.name).read_text(encoding='utf-8'))
        assert data.keys() == reference.keys(), (lang, source.name, 'keys')
        for key, value in data.items():
            assert sorted(re.findall(r'%\d+', value)) == sorted(re.findall(r'%\d+', reference[key])), (lang,key,'placeholders')
sandbox = (media/'sandbox-options.txt').read_text(encoding='utf-8')
blocks = re.findall(r'option\s+(\S+)\s*\{([^}]+)\}', sandbox)
expected = {'FertilizerCost','MildewCost','FliesCost','AphidsCost','SlugsCost'}
assert {name.split('.')[-1] for name,_ in blocks} == expected
en = json.loads((translations/'EN/Sandbox.json').read_text(encoding='utf-8'))
for name, block in blocks:
    pairs = dict(re.findall(r'(\w+)\s*=\s*([^,\s]+)',block))
    assert name.startswith('SuQingSprinklerFertilizer.') and pairs['type']=='double'
    assert (float(pairs['min']),float(pairs['max']),float(pairs['default'])) == (0.01,2,1)
    assert 'Sandbox_'+pairs['page'] in en
    assert 'Sandbox_'+pairs['translation'] in en
    assert 'Sandbox_'+pairs['translation']+'_tooltip' in en
meta = json.loads((root/'publishing/workshop.json').read_text(encoding='utf-8'))
version = meta['version']
info = (mod/'42/mod.info').read_text(encoding='utf-8')
assert 'id=SuQingSprinklerFertilizer' in info and 'require=Waterpipes' in info
for file in [mod/'42/mod.info',media/'lua/shared/SQSF/Resources.lua',root/'README.md',root/'CHANGELOG.md',mod/'README.txt']:
    assert version in file.read_text(encoding='utf-8'), (file,'version mismatch')
assert meta['required_workshop_ids'] == ['3546314080']
assert set(p.name for p in (root/'mods').iterdir()) == {'SuQingSprinklerFertilizer'}
assert not any(p.suffix in ('.class','.java','.zip','.bin','.db') for p in mod.rglob('*') if p.is_file())
items=(media/'scripts/SQSF_Items.txt').read_text(encoding='utf-8')
recipes=(media/'scripts/SQSF_Recipes.txt').read_text(encoding='utf-8')
item_blocks=dict(re.findall(r'item\s+(\w+)\s*\{([^}]+)\}',items))
assert len(item_blocks)==11
for size in (50,200):
    for kind in ('Mildew','Flies','Aphids','Slugs'):
        block=item_blocks[kind+'Pack'+str(size)]
        assert float(re.search(r'UseDelta\s*=\s*([.\d]+)',block)[1])==1/size
        assert 'ReplaceOnDeplete = SQSF.EmptyPack'+str(size) in block
        assert float(re.search(r'Weight\s*=\s*([.\d]+)',block)[1])==(1.3 if size==50 else 4.6)
recipe_ids=re.findall(r'craftRecipe\s+(\w+)',recipes)
assert len(recipe_ids)==len(set(recipe_ids))==24
data=json.loads((root/'docs/recipe-data.json').read_text(encoding='utf-8'))
assert {r['id'] for r in data}==set(recipe_ids)
for recipe in data:
    size=recipe['size'];scale=1 if size==50 else 4
    assert recipe['material_multiplier']==scale
    first=recipe['inputs'][0]
    assert first==(f'item 1 [SQSF.EmptyPack{size}] mode:destroy flags[ItemCount],' if recipe['refill'] else
                   f'item {1 if size==50 else 2} [Base.Plank] mode:destroy flags[ItemCount],')
    inputs='\n'.join(recipe['inputs']);water=1 if size==50 else 4
    assert 'GardeningSprayEmpty' not in inputs
    if recipe['kind']=='Mildew':assert f'-fluid {float(scale)} [CowMilk;SheepMilk;AnimalMilk]' in inputs and '[Water]' not in inputs
    else:assert f'-fluid {float(water)} [Water]' in inputs
    if recipe['kind']=='Aphids':assert f'-fluid {0.2*scale:.1f} [RubbingAlcohol]' in inputs
    if recipe['kind']=='Slugs':assert f'item {scale} [Base.Salt] mode:destroy flags[ItemCount]' in inputs
    if 'Cigarettes' in recipe['id']:assert f'item {5*scale} [Base.CigaretteSingle]' in inputs
    if 'Tobacco' in recipe['id']:assert f'item {8*scale} tags[base:tobacco]' in inputs
    if 'Chewing' in recipe['id']:assert f'item {5*scale}.0 [Base.TobaccoChewing]' in inputs
assert recipes.count('category = SuQingIrrigation,')==24
assert recipes.count('NeedToBeLearn = false,')==24
assert 'item 1 SQSF.CareResidue' not in recipes
for lang in ('CN','CH','EN'):
    labels=json.loads((translations/lang/'Recipes.json').read_text(encoding='utf-8'))
    assert set(recipe_ids)==set(labels)
    names=json.loads((translations/lang/'ItemName.json').read_text(encoding='utf-8'))
    assert {'SQSF.'+name for name in item_blocks}==set(names)
for key in ('Irrigation','Mildew','Flies','Aphids','Slugs','Empty'):
    png=(media/f'textures/Item_SQSF_{key}.png').read_bytes()
    assert png[:8]==b'\x89PNG\r\n\x1a\n'
    assert struct.unpack('>II',png[16:24])==(128,128)
    assert png[25]==6, (key,'must retain RGBA alpha')
assert (media/'ui/CategoryIcon/SuQingIrrigation.png').read_bytes()==(media/'textures/Item_SQSF_Irrigation.png').read_bytes()
print(json.dumps({'passed':True,'version':version,'translation_files':len(files)*3,'sandbox_options':len(blocks),
                  'recipes':24,'items':11,'rgba_icons':6,'small_pack_material_multiplier':1},ensure_ascii=False))
