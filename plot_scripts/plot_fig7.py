import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
import sys

# Input files
files = [sys.argv[1]]
plt.rcParams['pdf.fonttype'] = 42
plt.rcParams['ps.fonttype'] = 42
plt.figure(figsize=(6, 2))

plt.tick_params(axis='both', which='major', labelsize=12, left=False)
plt.tick_params(axis='both', which='minor', labelsize=12, left=False)

for filename in files:
    indices = []
    latencies = []
    with open(filename, "r") as f:
        for line in f:
            if line.strip():
                idx, lat = map(float, line.split())
                indices.append(idx)
                latencies.append(lat)
    plt.plot(indices, latencies, linewidth=1)


plt.xticks([6000, 12000, 18000, 24000])
plt.yticks([0.1, 0.3, 0.5])
plt.ylabel('Latency (ms)', fontsize=14)
plt.xlabel('Number of 2MB Allocations', fontsize=14)
plt.grid(True, linestyle='--', alpha=0.6)

plt.xlim(10, None)
plt.tight_layout()

# Save as high-resolution PDF
plt.savefig(sys.argv[2], dpi=500, bbox_inches='tight')
plt.close()
