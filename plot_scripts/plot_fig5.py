import matplotlib.pyplot as plt
from matplotlib.patches import Circle
from matplotlib.patches import Ellipse
import numpy as np
from math import pi
import sys
# Input file
filename = sys.argv[1]

# Read and process data
page_sizes = ["4KB", "64KB","2MB" ]
indices = []
page_points = {p: [] for p in page_sizes}
plt.rcParams['pdf.fonttype'] = 42
plt.rcParams['ps.fonttype'] = 42

with open(filename, "r") as f:
    for i, line in enumerate(f):
        entries = [x.strip().rstrip(',') for x in line.split() if x.strip()]
        for p in page_sizes:
            if p in entries:
                page_points[p].append(i)
        indices.append(i)

# Plot
plt.figure(figsize=(8, 3))
plt.grid(True, axis='x', linestyle='--', alpha=0.5, linewidth=1.5)
plt.grid(True, axis='y', linestyle='--', alpha=0.5, linewidth=1.5)
plt.tick_params(axis='both', which='major', labelsize=16, left=False)
plt.tick_params(axis='both', which='minor', labelsize=16, left=False)
plt.gca().set_axisbelow(True)
for p in page_sizes:
    plt.scatter(page_points[p], [p]*len(page_points[p]), label=p, s=20)

plt.ylabel('Page Type', fontsize=22)
plt.xlabel('Allocation Size', fontsize=22)
plt.yticks(page_sizes)
plt.xticks([0, 128, 256, 384, 512], ['0', '0.5MB', '1MB', '1.5MB', '2MB'])

handles, labels = plt.gca().get_legend_handles_labels()

# Reverse the order
handles = handles[::-1]
labels = labels[::-1]
plt.legend(handles=handles, labels=labels, loc="lower left", fontsize=12, markerscale=1.5, ncols=3)

u=520.     #x-position of the center
v=0    #y-position of the center
a=30.     #radius on the x-axis
b=0.1    #radius on the y-axis

t = np.linspace(0, 2*pi, 100)
plt.plot( u+a*np.cos(t) , v+b*np.sin(t) , linewidth=2, color="red", linestyle='-')

# last_4kb_index = page_points["4KB"][-1]
# last_4kb_y = "4KB"  # y-axis value is the page type

# # Add text annotation
# plt.text(last_4kb_index, last_4kb_y, "2MB + 64KB",
#          fontsize=10, ha='left', va='bottom', rotation=0, color='red')
# plt.tight_layout()

# Save as high-resolution PDF
plt.savefig(sys.argv[2], dpi=500, bbox_inches='tight')
plt.close()