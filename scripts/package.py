#!/usr/bin/env python3
"""Make a portable archive without Finder metadata; preserve executable bits."""
from pathlib import Path
import hashlib
import sys
import zipfile

app, output = map(Path, sys.argv[1:3])
output.mkdir(parents=True, exist_ok=True)
archive = output / 'OldLocal-macOS-arm64.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as package:
    for path in sorted(app.rglob('*')):
        if path.is_symlink():
            raise ValueError('Unexpected symlink in application')
        if path.is_file():
            info = zipfile.ZipInfo(str(path.relative_to(app.parent)))
            info.create_system = 3
            info.external_attr = (path.stat().st_mode & 0xFFFF) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            package.writestr(info, path.read_bytes())
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(output / 'SHA256SUMS').write_text(f'{digest}  {archive.name}\n')
print(archive)
