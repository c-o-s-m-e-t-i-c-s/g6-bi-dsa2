"""Package the verified Python runtime tree for EC2."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import stat
import tarfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for arg in ('root', 'out', 'project', 'repository-id', 'revision', 'run-id', 'run-attempt'):
        parser.add_argument(f'--{arg}', required=True)
    args = parser.parse_args()
    root = Path(args.root)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    manifest = dict(format=2, project=args.project, repository_id=args.repository_id,
                    revision=args.revision, ref='refs/heads/main', run_id=args.run_id, run_attempt=args.run_attempt)
    contents = json.dumps(manifest, sort_keys=True).encode()
    total = 0
    count = 0
    with tarfile.open(out, 'w:gz') as archive:
        info = tarfile.TarInfo('manifest.json')
        info.size, info.mode = len(contents), 0o644
        archive.addfile(info, io.BytesIO(contents))
        for path in sorted(root.rglob('*')):
            relative = path.relative_to(root).as_posix()
            if any(part.startswith('.') or part == '__pycache__' for part in relative.split('/')):
                continue
            mode = path.lstat().st_mode
            if stat.S_ISDIR(mode):
                continue
            if (not stat.S_ISREG(mode) or path.suffix.lower() in {'.db', '.sqlite', '.sqlite3', '.pyc'}
                    or not re.fullmatch(r'(app|vendor|static)/[A-Za-z0-9_+-][A-Za-z0-9_+./-]{0,235}', relative)):
                raise SystemExit(f'Unexpected release file: {relative}')
            size = path.stat().st_size
            total += size
            count += 1
            if total > 160 * 1024 * 1024 or count >= 18000:
                raise SystemExit('Expanded release exceeds limits')
            info = tarfile.TarInfo(relative)
            info.size, info.mode = size, 0o644
            with path.open('rb') as stream:
                archive.addfile(info, stream)
    if not count or out.stat().st_size > 64 * 1024 * 1024:
        raise SystemExit('Compressed release exceeds limits or is empty')
    with out.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    print(f'archive={out} files={count} expanded={total} compressed={out.stat().st_size} sha256={digest}')


if __name__ == '__main__':
    main()
