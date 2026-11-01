"""Compile all package Lua and run actual vanilla farming methods in game Kahlua.
Game UI is never launched. Java API objects are controlled fixtures.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess, re

parser = argparse.ArgumentParser()
parser.add_argument('--game', type=Path, required=True)
parser.add_argument('--water-pipes', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
game = args.game.resolve()
out = root/'validation'; out.mkdir(exist_ok=True)
lua = root/'mods/SuQingSprinklerFertilizer/42/media/lua'
wp = args.water_pipes.resolve()
files = sorted(lua.rglob('*.lua'))
# Generate ASCII-safe Lua literals, retaining UTF-8 source bytes for compilation.
def literal(text):
    return '"'+''.join(chr(b) if 32 <= b <= 126 and b not in (34,92) else '\\%03d'%b for b in text.encode('utf-8'))+'"'
compile_script = '\n'.join('assert(loadstring('+literal(p.read_text(encoding='utf-8'))+','+literal(p.name)+'))' for p in files)
# Exercise real source-reader compatibility checks with currently installed input.
reader = ['local sources = {}']
for name in ['media/lua/server/WPServer.lua','media/lua/shared/WPIso.lua']:
    lines = (wp/name).read_text(encoding='utf-8-sig').splitlines()
    reader.append('sources['+literal(name)+']={'+','.join(map(literal,lines))+'}')
reader.append('function getModFileReader(mod,path) local lines=sources[path]; if not lines then return end; local i=0; return {readLine=function()i=i+1;return lines[i]end,close=function()end} end')
(out/'syntax.lua').write_text(compile_script,encoding='utf-8')
(out/'reader.lua').write_text('\n'.join(reader),encoding='utf-8')
inputs = [out/'syntax.lua', root/'tests/prelude_v3.lua', game/'media/lua/shared/ISBaseObject.lua',
          game/'media/lua/server/Map/SGlobalObject.lua', game/'media/lua/server/Farming/SPlantGlobalObject.lua',
          out/'reader.lua', lua/'shared/SQSF/Resources.lua', lua/'shared/SQSF/Network.lua', lua/'shared/SQSF/Core.lua', root/'tests/resources_v3.lua', root/'tests/network_v3.lua',
          game/'media/lua/shared/TimedActions/ISBaseTimedAction.lua', root/'tests/ui_fixture_v3.lua', game/'media/lua/client/ISUI/ISComboBox.lua', lua/'client/SQSF/DeviceView.lua', lua/'client/SQSF/Client.lua', lua/'client/SQSF/ManagementWindow.lua', root/'tests/ui_v4.lua',root/'tests/controls_v5.lua',
          wp/'media/lua/shared/WPUtils.lua',wp/'media/lua/server/WPServer.lua',root/'tests/upstream_v3.lua']
cmd=[str(game/'jre64/bin/java.exe'),'-cp',str(game/'projectzomboid.jar')+';'+str(out),'KahluaValidation',*map(str,inputs)]
result=subprocess.run(cmd,cwd=game,capture_output=True,text=True,encoding='utf-8',errors='replace')
native_cmd=[str(game/'jre64/bin/java.exe'),'--enable-native-access=ALL-UNNAMED','-cp',str(game/'projectzomboid.jar')+';'+str(out),
            'NativeValidation',str(lua.parent/'sandbox-options.txt'),str(lua.parent/'scripts/SQSF_Items.txt'),str(lua.parent/'scripts/SQSF_Recipes.txt')]
native=subprocess.run(native_cmd,cwd=game,capture_output=True,text=True,encoding='utf-8',errors='replace')
text=result.stdout+result.stderr+native.stdout+native.stderr
(out/'test-output.txt').write_text(text,encoding='utf-8')
match=re.search(r'upstream_v3.lua: \[true, (\d+)',text)
native_match=re.search(r'Native validation passed: (\d+) checks',text)
report={'passed':result.returncode==0 and bool(match) and native.returncode==0,
        'assertions':int(match[1]) if match else 0,'native_checks':int(native_match[1]) if native_match else 0,
        'runtime':'installed game Kahlua; real SPlantGlobalObject with controlled Java fixtures',
        'gameplay_verified':False,'source_hashes':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
(out/'test-result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(text);print(json.dumps(report,ensure_ascii=False))
raise SystemExit(0 if report['passed'] else 1)
