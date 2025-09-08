import sys
import re

f = open(sys.argv[1])
pattern = r'.*[>-]([\w\d]+)@(0x[0-9a-fA-F]+)'
map = {}
for line in f:
    match = re.match(pattern, line)
    if not match:
        continue

    map[match.group(2)] = match.group(1)
    # print("Before @:", match.group(1))
    # print("After @:", match.group(2))
sorted_dict = dict(sorted(map.items(), key=lambda item: int(item[0], 16)))
for k, v in sorted_dict.items():
    print(k, ":", v)
