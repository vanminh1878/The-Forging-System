import sys, glob
import tree_sitter_dart as d
from tree_sitter import Language, Parser
lang = Language(d.language())
p = Parser(lang)
bad = 0
def walk(n, errs):
    if n.type == 'ERROR' or n.is_missing:
        errs.append(n)
        return
    for c in n.children:
        walk(c, errs)
files = []
for a in sys.argv[1:]:
    files += glob.glob(a + '/**/*.dart', recursive=True)
for f in sorted(files):
    src = open(f, 'rb').read()
    t = p.parse(src)
    errs = []
    if t.root_node.has_error:
        walk(t.root_node, errs)
        for e in errs[:5]:
            print(f"{f}:{e.start_point[0]+1}:{e.start_point[1]+1} {'MISSING '+e.type if e.is_missing else 'ERROR'}")
        bad += 1
print(f"checked {len(files)} files, {bad} with syntax errors")
sys.exit(1 if bad else 0)
