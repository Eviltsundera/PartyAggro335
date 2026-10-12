"""Create the installable archive with one correctly named AddOns directory."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import re

root = Path(__file__).resolve().parents[1]
addon = root / 'PartyAggro335'
toc = (addon / 'PartyAggro335.toc').read_text(encoding='utf-8')
version = re.search(r'^## Version:\s*(\S+)', toc, re.M).group(1)
destination = root / 'dist'
destination.mkdir(exist_ok=True)
archive = destination / f'PartyAggro335-{version}.zip'
with ZipFile(archive, 'w', ZIP_DEFLATED) as output:
    for path in sorted(addon.rglob('*')):
        if path.is_file():
            output.write(path, path.relative_to(root).as_posix())
    output.write(root / 'LICENSE', 'PartyAggro335/LICENSE.txt')
with ZipFile(archive) as check:
    assert check.testzip() is None
    assert 'PartyAggro335/PartyAggro335.toc' in check.namelist()
print(archive)
