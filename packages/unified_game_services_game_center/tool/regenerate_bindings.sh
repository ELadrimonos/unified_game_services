#!/usr/bin/env bash
# Regenerates the committed GameKit bindings. Requires macOS + Xcode.
#
#   ./tool/regenerate_bindings.sh
#
# ffigen 21-dev propagates @Deprecated annotations from the GameKit headers,
# and some land on extension-type declarations where the analyzer rejects them
# (`invalid_annotation`). We never call the deprecated members, so we strip
# every @Deprecated(...) annotation after generation.
set -euo pipefail
cd "$(dirname "$0")/.."

dart run ffigen --config ffigen_gamekit.yaml

python3 - <<'PY'
f = 'lib/src/gamekit_bindings.dart'
s = open(f).read()
out = []; i = 0; n = len(s)
while i < n:
    if s.startswith('@Deprecated(', i):
        depth = 0; j = i + len('@Deprecated')
        while j < n:
            if s[j] == '(': depth += 1
            elif s[j] == ')':
                depth -= 1
                if depth == 0:
                    j += 1; break
            j += 1
        while j < n and s[j] in ' \t': j += 1
        if j < n and s[j] == '\n': j += 1
        while out and out[-1] in ' \t': out.pop()
        i = j
        continue
    out.append(s[i]); i += 1
open(f, 'w').write(''.join(out))
print('stripped @Deprecated annotations')
PY

dart format lib/src/gamekit_bindings.dart >/dev/null
echo "Bindings regenerated."
