"""Count actual upstream exclusions, preserving reasons and per-side evidence."""
from pathlib import Path
import csv
import sys


def read(path):
    if not path.exists():
        return None
    with path.open() as stream:
        rows = list(csv.reader(stream, delimiter='\t'))
    if any(len(row) != 3 or not all(row) for row in rows):
        raise ValueError('invalid exclusion audit')
    result = {'#'.join(row[:2]): row[2] for row in rows}
    if len(result) != len(rows):
        raise ValueError('duplicate exclusion audit')
    return result


def compare(prefix):
    ref = read(Path(str(prefix) + '.ref.excluded'))
    mere = read(Path(str(prefix) + '.mere.excluded'))
    if ref is None or mere is None or ref != mere:
        raise ValueError('reference and mere-ruby exclusions differ or audit is missing')
    return ref


if __name__ == '__main__':
    prefix, file = Path(sys.argv[1]), sys.argv[2]
    entries = compare(prefix)
    Path(str(prefix) + '.exclusions').write_text(''.join(
        f'{file}\t{name}\t{reason}\n' for name, reason in sorted(entries.items())))
