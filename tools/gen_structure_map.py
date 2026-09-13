#!/usr/bin/env python3
"""Where a definition lives, and what it can see.

    python3 tools/gen_structure_map.py > STRUCTURE.md

Mere's visibility boundary is not the FILE and not the `module` -- it is the
`let rec ... and ...` chain.  Two chains in one file cannot be mutually
recursive (measured: `let rec f = ... g ...; let rec g = ... f ...` is
"unbound variable: g"), and `import` splices declarations at the import
point, so it cannot cross one either.  A helper added to the wrong chain is
invisible to its caller, which is a build error -- and a helper added under a
name that already exists in the SAME chain is silently dead, which is not.
tools/dup_defs_check.sh refuses the second; this map is for the first.

The SCC section says which functions are genuinely mutually recursive.  A
function outside every cycle could be moved to its own module today, in
topological order, with the one-way `import` the language already has; one
inside the big cycle could not, whatever the module system looked like.
"""
import io, re, sys, collections

SRC = sys.argv[1] if len(sys.argv) > 1 else "main.mere"
L = io.open(SRC, encoding="utf-8", errors="replace").read().split("\n")
DEF = re.compile(r"^(and|let rec|let) ([a-z_][a-z_0-9]*) = fn")
WORD = re.compile(r"[a-z_][a-z_0-9]*")

chains, owner, defline = [], [None] * len(L), {}
cur_chain = -1
for i, l in enumerate(L):
    m = DEF.match(l)
    if m:
        name = m.group(2)
        if m.group(1) != "and":
            cur_chain += 1
            chains.append({"head": name, "start": i + 1, "names": []})
        if chains:
            chains[cur_chain]["names"].append(name)
        defline.setdefault(name, i + 1)
    owner[i] = None if cur_chain < 0 else cur_chain
    if m: owner[i] = cur_chain
for n, c in enumerate(chains):
    c["end"] = (chains[n + 1]["start"] - 1) if n + 1 < len(chains) else len(L)
    c["lines"] = c["end"] - c["start"] + 1

# call graph among top-level names, attributed to the enclosing definition
fn_of = [None] * len(L); cur = None
for i, l in enumerate(L):
    m = DEF.match(l)
    if m: cur = m.group(2)
    fn_of[i] = cur
names = set(defline)
edges = {n: set() for n in names}
for i, l in enumerate(L):
    o = fn_of[i]
    if o is None: continue
    for w in set(WORD.findall(l.split("//")[0])):
        if w in names and w != o: edges[o].add(w)

# Tarjan, iterative
index, low, onstk, stk, idx, comps = {}, {}, {}, [], [0], []
def scc(root):
    work = [(root, 0)]
    while work:
        v, pi = work[-1]
        if pi == 0:
            index[v] = low[v] = idx[0]; idx[0] += 1; stk.append(v); onstk[v] = True
        rec = False; succ = sorted(edges[v])
        for k in range(pi, len(succ)):
            w = succ[k]
            if w not in index:
                work[-1] = (v, k + 1); work.append((w, 0)); rec = True; break
            elif onstk.get(w): low[v] = min(low[v], index[w])
        if rec: continue
        if low[v] == index[v]:
            c = []
            while True:
                w = stk.pop(); onstk[w] = False; c.append(w)
                if w == v: break
            comps.append(c)
        work.pop()
        if work:
            u = work[-1][0]; low[u] = min(low[u], low[v])
for n in sorted(names):
    if n not in index: scc(n)
comps.sort(key=len, reverse=True)
scc_of = {n: k for k, c in enumerate(comps) for n in c}
def scc_lines(c):
    s = set(c); return sum(1 for i in range(len(L)) if fn_of[i] in s)

out = []
w = out.append
w("# mere-ruby — where a definition lives, and what it can see\n")
w("\n".join(__doc__.split("\n")[3:]).strip() + "\n")
w("Regenerate with `python3 tools/gen_structure_map.py > STRUCTURE.md`.\n")
w(f"`{SRC}`: **{len(L)}** lines, **{len(names)}** top-level functions, "
  f"**{len(chains)}** chains, **{len(comps)}** strongly-connected components.\n")

w("## Chains — the visibility boundary\n")
w("A definition can be referenced from anywhere in ITS chain (that is what")
w("`and` buys) and only from BELOW it anywhere else. Chains under 20 lines")
w("are folded into the count at the end.\n")
w("| lines | at | head of chain | functions |")
w("|---|---|---|---|")
small = 0
for c in chains:
    if c["lines"] < 20: small += 1; continue
    w(f"| {c['lines']} | {c['start']} | `{c['head']}` | {len(c['names'])} |")
w(f"\n...and {small} chains shorter than 20 lines.\n")

w("## Cycles — what could be split, and what could not\n")
w("| functions | lines | kind | e.g. |")
w("|---|---|---|---|")
for c in comps[:6]:
    if len(c) < 2: continue
    w(f"| {len(c)} | {scc_lines(c)} | mutually recursive | {', '.join(sorted(c)[:4])} |")
acyclic = [n for n in names if len(comps[scc_of[n]]) == 1]
w(f"| {len(acyclic)} | {sum(1 for i in range(len(L)) if fn_of[i] in set(acyclic))} "
  f"| in no cycle | — |")
w("\nA function \"in no cycle\" has no path back to itself through the call")
w("graph, so nothing but ordering keeps it here: it could be a module today.")
w("One inside a cycle needs mutual recursion across whatever boundary you put")
w("between the halves, and Mere has no way to write that.\n")

w("## The chain each function is in\n")
w("Sorted by name. `scc` is the size of its cycle (1 = not in one).\n")
w("| function | line | chain | scc |")
w("|---|---|---|---|")
for n in sorted(names):
    ln = defline[n]
    ci = next((k for k, c in enumerate(chains) if c["start"] <= ln <= c["end"]), -1)
    w(f"| `{n}` | {ln} | {chains[ci]['head'] if ci >= 0 else '—'} | {len(comps[scc_of[n]])} |")
print("\n".join(out))
