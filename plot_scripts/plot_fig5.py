import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
import sys

filename = sys.argv[1]
outfile = sys.argv[2]

page_sizes = ["2MB", "4KB", "64KB"]
page_points = {p: [] for p in page_sizes}

with open(filename, "r") as f:
    for i, line in enumerate(f):
        entries = [x.strip().rstrip(',') for x in line.split() if x.strip()]
        for p in page_sizes:
            if p in entries:
                page_points[p].append(i)

n = max(max(v) for v in page_points.values() if v) + 1

def presence(indices, n):
    arr = np.zeros(n, dtype=int)
    for idx in indices:
        arr[idx] = 1
    return arr

active = {p: presence(page_points[p], n) for p in page_sizes}

# X axis: each index is a 4KB step
x = np.arange(n)
x_kb = x * 4  # in KB

def kb_label(kb):
    if kb == 0:
        return '0'
    elif kb % 1024 == 0:
        return f'{kb // 1024}MB'
    elif kb >= 1024:
        return f'{kb // 1024}MB+{kb % 1024}KB'
    else:
        return f'{kb}KB'

# Stack order: 2MB at bottom, then 4KB, then 64KB
stack_order = ["2MB", "4KB", "64KB"]
colors = {"2MB": "#1D9E75", "4KB": "#378ADD", "64KB": "#D85A30"}
alphas = {"2MB": 0.6, "4KB": 0.6, "64KB": 0.6}

plt.rcParams['pdf.fonttype'] = 42
plt.rcParams['ps.fonttype'] = 42

fig, ax = plt.subplots(figsize=(8, 3))

bottom = np.zeros(n)
for p in stack_order:
    y = active[p].astype(float)
    ax.fill_between(x_kb, bottom, bottom + y,
                    step='mid',
                    alpha=alphas[p],
                    color=colors[p],
                    linewidth=0)
    ax.step(x_kb, bottom + y,
            where='mid',
            color=colors[p],
            linewidth=1.5)
    bottom = bottom + y

# X ticks: fixed at 0, 0.5MB, 1MB, 1.5MB, 2MB (in KB units)
tick_kb = [0, 512, 1024, 1536, 2048]
tick_labels = ['0', '0.5MB', '1MB', '1.5MB', '2MB']
ax.set_xticks(tick_kb)
ax.set_xticklabels(tick_labels, fontsize=11)

ax.set_yticks(range(len(stack_order) + 1))
ax.set_ylabel('Active page types', fontsize=16)
ax.set_xlabel('Allocation size (each step = +4KB)', fontsize=16)
ax.set_ylim(0, len(stack_order))
ax.tick_params(axis='both', labelsize=16)

ax.grid(True, axis='x', linestyle='--', alpha=0.4, linewidth=1)
ax.grid(True, axis='y', linestyle='--', alpha=0.4, linewidth=1)
ax.set_axisbelow(True)

legend_patches = [
    mpatches.Patch(color=colors[p], alpha=0.7, label=p)
    for p in reversed(stack_order)
]
ax.legend(handles=legend_patches, fontsize=12, loc='upper left',
          framealpha=0.8, ncols=3)

plt.tight_layout()
plt.savefig(outfile, dpi=300, bbox_inches='tight')
plt.close()
print(f"Saved to {outfile}")