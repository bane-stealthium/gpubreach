#!/usr/bin/env python3
import re
import sys
import os

BASE_PTE_VALUE = 0x0600000000000005


def parse_int(s: str) -> int:
    s = s.strip().lower()
    return int(s, 16) if s.startswith("0x") else int(s)


def calc_new_pte_value(iova: int) -> int:
    return BASE_PTE_VALUE + (iova >> 4)


def parse_alloc_file(text: str):
    
    root = {}

    # Matches e.g. "PD3@0x000d400000"
    level_re = re.compile(r'^(?P<indent>\s*)(?P<kind>PD[0-3]|PT)@(?P<addr>0x[0-9a-fA-F]+)\s*$')

    # Matches e.g. "  0-->PD2@0x000ca35000"
    child_level_re = re.compile(
        r'^(?P<indent>\s*)(?P<idx>\d+)-->(?P<kind>PD[0-3]|PT)@(?P<addr>0x[0-9a-fA-F]+)\s*$'
    )

    # Matches e.g.
    # " 177-->2MB-Page@0x000cb14000 VA: 0x40836200000 ..."
    page_entry_re = re.compile(
        r'^(?P<indent>\s*)(?P<idx>\d+)-->'
        r'(?P<kind>[^@]+)@(?P<page_pa>0x[0-9a-fA-F]+)\s+VA:\s*(?P<va>0x[0-9a-fA-F]+).*?$'
    )

    # stack entries: (indent_len, node_dict)
    stack = []

    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        if not line.strip():
            continue

        # Top-level PD3/PT line
        m = level_re.match(line)
        if m:
            indent = len(m.group("indent"))
            kind = m.group("kind")
            addr = int(m.group("addr"), 16)

            if kind == "PD3":
                node = {
                    "type": "PD3",
                    "addr": addr,
                    "children": {}
                }
                root[addr] = node
                stack = [(indent, node)]
            else:
                # Ignore standalone non-PD3 root
                stack = []
            continue

        # Child level line: idx-->PDx@addr or idx-->PT@addr
        m = child_level_re.match(line)
        if m:
            indent = len(m.group("indent"))
            idx = int(m.group("idx"))
            kind = m.group("kind")
            addr = int(m.group("addr"), 16)

            while stack and stack[-1][0] >= indent:
                stack.pop()

            if not stack:
                continue

            parent = stack[-1][1]

            node = {
                "type": kind,
                "addr": addr,
                "children": {} if kind in ("PD3", "PD2", "PD1") else {},
                "entries": {} if kind in ("PD0", "PT") else None,
                "index_in_parent": idx,
            }

            parent.setdefault("children", {})[idx] = node
            stack.append((indent, node))
            continue

        # Page/PT entry line
        m = page_entry_re.match(line)
        if m:
            indent = len(m.group("indent"))
            idx = int(m.group("idx"))
            kind = m.group("kind").strip()
            page_pa = int(m.group("page_pa"), 16)
            va = int(m.group("va"), 16)

            while stack and stack[-1][0] >= indent:
                stack.pop()

            if not stack:
                continue

            parent = stack[-1][1]
            if parent["type"] not in ("PD0", "PT"):
                continue

            parent["entries"][idx] = {
                "kind": kind,
                "page_pa": page_pa,
                "va": va,
                "raw": line,
            }

    return root


def collect_pd0_nodes(tree):
    result = []

    def walk(node):
        if node["type"] == "PD0":
            result.append(node)

        for child in node.get("children", {}).values():
            walk(child)

    for pd3 in tree.values():
        walk(pd3)

    return result


def find_target_pd0(tree):
    pd0_nodes = collect_pd0_nodes(tree)

    for pd0 in pd0_nodes:
        entries = pd0.get("entries", {})
        if len(entries) != 256:
            continue

        # Require exact indices 0..255
        if sorted(entries.keys()) != list(range(256)):
            continue

        if not all(e["kind"] == "2MB-Page" for e in entries.values()):
            continue

        first_idx = 0
        first_entry = entries[first_idx]
        selected_pte_addr = pd0["addr"] + first_idx * 8

        return {
            "pd0_addr": pd0["addr"],
            "entry_idx": first_idx,
            "selected_va": first_entry["va"],
            "selected_pte_addr": selected_pte_addr,
            "page_pa": first_entry["page_pa"],
            "entry_kind": first_entry["kind"],
        }

    raise RuntimeError("No PD0 found with 256 entries where all entries are 2MB-Page.")


def main():
    if len(sys.argv) != 3:
        print(
            f"Usage: {sys.argv[0]} <alloc.txt> <iova_hex>\n"
            f"Example: {sys.argv[0]} alloc.txt 0xffe00000",
            file=sys.stderr,
        )
        sys.exit(1)

    alloc_file = sys.argv[1]
    iova = parse_int(sys.argv[2])

    with open(alloc_file, "r", encoding="utf-8") as f:
        text = f.read()

    tree = parse_alloc_file(text)
    target = find_target_pd0(tree)
    new_pte_value = calc_new_pte_value(iova)

    cmd = (
        f"0x{target['selected_pte_addr']:016x} "
        f"0x{new_pte_value:016x} --write"
    )

    print(f"selected_va=0x{target['selected_va']:016x}", file=sys.stderr)
    print(cmd)


if __name__ == "__main__":
    main()