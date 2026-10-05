"""Approximate import checker for project files (no SDK available).

Reports symbols declared in another project file that are used without a
matching import, and project imports whose declared symbols are never used.
Usage: python3 tool/check_imports.py lib test
"""
import glob
import os
import re
import sys

DECL = re.compile(
    r"^(?:abstract\s+|final\s+|base\s+|sealed\s+|interface\s+)*"
    r"(?:class|enum|mixin|extension type|typedef)\s+([A-Za-z_]\w*)", re.M)
FUNC = re.compile(r"^(?:[\w<>?,\s\(\)\$]+?\s)?([a-zA-Z_]\w*)\s*(?:<[^>]*>)?\s*\([^;{]*\)\s*(?:async\s*)?(?:=>|\{)", re.M)
VAR = re.compile(r"^(?:final|const)\s+(?:[\w<>?,\s]+\s)?([a-zA-Z_]\w*)\s*=", re.M)
EXT = re.compile(r"^extension\s+([A-Za-z_]\w*)", re.M)


def strip(src):
    src = re.sub(r"//[^\n]*", "", src)
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    return src


def declared(path):
    src = strip(open(path, encoding="utf-8").read())
    names = set(DECL.findall(src)) | set(EXT.findall(src))
    names |= set(VAR.findall(src))
    for m in re.finditer(r"^[A-Za-z_][\w<>?,\s]*\s([a-z]\w*)\s*(?:<[^>]*>)?\s*\(", src, re.M):
        names.add(m.group(1))
    # Members of extensions are used without naming the extension.
    for ext in re.finditer(r"^extension\s+\w+\s+on\s+[^{]+\{(.*?)^\}", src, re.M | re.S):
        body = ext.group(1)
        names |= set(re.findall(r"\bget\s+([a-zA-Z_]\w*)", body))
        names |= set(re.findall(r"\b[A-Z]\w*\??\s+([a-z]\w*)\s*\(", body))
    return {n for n in names if not n.startswith("_")}


def resolve(f, imp):
    if imp.startswith("package:hvp_forging/"):
        return "lib/" + imp[len("package:hvp_forging/"):]
    if imp.startswith(("package:", "dart:")):
        return None
    return os.path.normpath(os.path.join(os.path.dirname(f), imp))


files = []
for a in sys.argv[1:]:
    files += glob.glob(a + "/**/*.dart", recursive=True)
decls = {f: declared(f) for f in files}
problems = 0
for f in sorted(files):
    raw = open(f, encoding="utf-8").read()
    src = strip(raw)
    body = re.sub(r"^(import|export|part)[^;]*;", "", src, flags=re.M)
    tokens = set(re.findall(r"[A-Za-z_]\w*", body))
    imports = [resolve(f, m) for m in re.findall(r"^import '([^']+)'", src, re.M)]
    imports = [i for i in imports if i and i in decls]
    own = decls[f]
    avail = set()
    for i in imports:
        avail |= decls[i]
    for other, names in decls.items():
        if other == f or other in imports:
            continue
        for n in names:
            if n in tokens and n not in own and n not in avail and (n[0].isupper() or len(n) > 6):
                print(f"{f}: uses '{n}' declared in {other} but no import")
                problems += 1
    for i in imports:
        if not (decls[i] & tokens):
            print(f"{f}: import of {i} looks unused")
            problems += 1
print("problems:", problems)
