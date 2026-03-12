import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
import sys

# Input files
# files = ["ev_ptp_2MB.txt", "ev_ptp_4MB.txt"]
# labels = ["Leave 2MB Free", "Leave 4MB Free"]
files = [sys.argv[1], sys.argv[2]]
labels = ["Leave 2MB Free", "Leave 4MB Free"]
plt.rcParams['pdf.fonttype'] = 42
plt.rcParams['ps.fonttype'] = 42
plt.figure(figsize=(6, 2))

plt.tick_params(axis='both', which='major', labelsize=12, left=False)
plt.tick_params(axis='both', which='minor', labelsize=12, left=False)

for filename, label in zip(files, labels):
    indices = []
    latencies = []
    with open(filename, "r") as f:
        for line in f:
            if line.strip():
                idx, lat = map(float, line.split())
                indices.append(idx)
                latencies.append(lat)
    plt.plot(indices, latencies, label=label, linewidth=1)


plt.xticks([200, 400, 600, 800])
plt.ylabel('Latency (ms)', fontsize=14)
plt.xlabel('4KB Page Tables Allocated', fontsize=14)
plt.grid(True, linestyle='--', alpha=0.6)
legend = plt.legend(fontsize=12,loc="upper right")
for line in legend.get_lines():
    line.set_linewidth(3)

# plt.gca().xaxis.set_major_formatter(FuncFormatter(lambda x, _: int(x * 3)))
plt.xlim(10, None)
plt.tight_layout()

# Save as high-resolution PDF
plt.savefig(sys.argv[-1], dpi=500, bbox_inches='tight')
plt.close()
