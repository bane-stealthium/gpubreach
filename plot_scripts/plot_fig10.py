import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import sys

# Path to your data file
filename = sys.argv[1]
plt.rcParams['pdf.fonttype'] = 42
plt.rcParams['ps.fonttype'] = 42

# Read data
indices = []
latencies = []
with open(filename, "r") as f:
    for line in f:
        if line.strip():  # skip empty lines
            idx, lat = map(float, line.split())
            indices.append(idx)
            latencies.append(lat)

# Plot
plt.figure(figsize=(8, 3))
plt.tick_params(axis='both', which='major', labelsize=16, left=False)
plt.tick_params(axis='both', which='minor', labelsize=16, left=False)

highlight_color_PTP = "red"
text_offset = 0.02  # vertical offset for text labels

# Find spike points
PTP_spike_indices = [i for i, lat in enumerate(latencies) if lat > 0.2 ]
PTP_spike_x = [indices[i] for i in PTP_spike_indices]
PTP_spike_y = [latencies[i] for i in PTP_spike_indices]

plt.plot(indices, latencies, marker='o', linestyle='-', linewidth=1)

# Highlight spikes
plt.scatter(PTP_spike_x, PTP_spike_y, color=highlight_color_PTP, s=50, zorder=3)

# Add text labels for spikes
for x, y in zip(PTP_spike_x, PTP_spike_y):
    plt.text(x, y + text_offset, f"{int(x)}", color=highlight_color_PTP,
             fontsize=16, ha='right', va='bottom', rotation=0)

plt.yticks([ 0.1, 0.3, 0.5])
plt.ylabel('Latency\n(ms)', fontsize=22)
plt.xlabel('4KB Page Frames Allocated', fontsize=22)
plt.grid(True, linestyle='--', alpha=0.6)
legend_elements = [
    # Line2D([0], [0], color=highlight_color_MEM, lw=0, marker='o', label='Memory Allocation', markersize=8),
    Line2D([0], [0], color=highlight_color_PTP, lw=1, marker='o', label='PT Region Allocation'),
]

# plt.legend(handles=legend_elements, fontsize=12, loc="upper center", ncols=2, bbox_to_anchor=(0.5, 1))
plt.tight_layout()


plt.savefig(sys.argv[2], dpi=500, bbox_inches='tight')
plt.close()