"""Run real Lua 5.1 tests and syntax checks; no WoW client required."""
from pathlib import Path
import sys
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().PROJECT_ROOT = ROOT.as_posix()
version = lua.eval('_VERSION')
assert version == 'Lua 5.1', version
for path in sorted((ROOT / 'PartyAggro335').glob('*.lua')):
    result = lua.eval('function(source, name) return loadstring(source, name) end')(
        path.read_text(encoding='utf-8'), '@' + path.name
    )
    if isinstance(result, tuple) and result[0] is None:
        raise RuntimeError(f'{path.name}: {result[1]}')
for name in ('core_spec.lua', 'wow_spec.lua', 'nameplate_spec.lua'):
    print(f'Running {name} under {version}...', flush=True)
    lua.execute((ROOT / 'tests' / name).read_text(encoding='utf-8'))
print('All Lua 5.1 tests and addon syntax checks passed.')
