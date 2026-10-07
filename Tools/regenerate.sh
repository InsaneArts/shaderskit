#!/usr/bin/env bash
# Regenerates Sources/ShadersKit/Generated, Resources/MSL and Resources/Descriptors from upstream.
#
#   Tools/regenerate.sh [upstream-ref]        # default: main
#
# Requires: node >= 20, pnpm, Xcode command line tools (for --validate).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF="${1:-main}"
WORK="${SHADERS_WORK:-$ROOT/Tools/.build}"
UPSTREAM="$WORK/upstream"
DUMP="$WORK/dump"
mkdir -p "$WORK"

if [ ! -d "$UPSTREAM/.git" ]; then
  git clone --depth 1 --branch "$REF" https://github.com/shader-effects-inc/shaders "$UPSTREAM"
else
  git -C "$UPSTREAM" fetch --depth 1 origin "$REF" && git -C "$UPSTREAM" checkout -q FETCH_HEAD
fi

echo "▸ installing upstream dependencies"
(cd "$UPSTREAM" && pnpm install --frozen-lockfile >/dev/null)

echo "▸ dumping WGSL for every shader (GPU-free)"
cp "$ROOT"/Tools/upstream-dump/zz-dump*.test.ts "$UPSTREAM/packages/core/src/__tests__/gpu/"
rm -rf "$DUMP"
(cd "$UPSTREAM/packages/core" && DUMP_OUT="$DUMP" pnpm vitest run zz-dump >/dev/null)
node -e '
const fs=require("fs"); const out={}; const dir=process.argv[1];
for (const d of fs.readdirSync(dir)) { const f=dir+"/"+d+"/index.ts"; if(!fs.existsSync(f)) continue; const s=fs.readFileSync(f,"utf8");
  out[d]={role:(s.match(/role:\s*\x27([a-zA-Z]+)\x27/)||[])[1]||null, species:(s.match(/species:\s*\x27([a-zA-Z]+)\x27/)||[])[1]||null}; }
fs.writeFileSync(process.argv[2], JSON.stringify(out,null,1));' "$UPSTREAM/packages/core/src/shaders" "$ROOT/Tools/upstream-dump/roles.json"

echo "▸ transpiling to Metal + Swift"
(cd "$ROOT/Tools/wgsl2x" && npm install --silent && npx tsx src/main.ts "$DUMP" "$ROOT" --validate && npx tsx src/gen-docs.ts "$ROOT")

echo "▸ done. Run: swift build && swift test"
