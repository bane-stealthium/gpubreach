import sys

def retrieve_ptes(pagemap):
  with open(pagemap, 'r') as f:
    lines = f.readlines()
  
  ptes = dict()
  tabs = [0, 0]  
  for ent in lines:
    parts = ent.strip().split('-->')
    if 'PD0' in ent:
      tabs[0] = int(parts[1].split('@')[1], 16)
    elif 'PT' in ent:
      tabs[1] = int(parts[1].split('@')[1], 16)
    elif 'Page' in ent:
      idx = int(parts[0])
      parts = parts[1].split('@')
      addrs = parts[1].split('VA:')
      pa_str = addrs[0].strip()
      va_str = addrs[1].strip().split()[0]
      pa = int(pa_str, 16)
      va = int(va_str, 16)
      epa = tabs[0] + 16 * idx if '2MB' in ent else tabs[1] + 8 * idx
      ptes[va] = [hex(pa), hex(epa), hex(make_pte_value(pa))]
  return ptes

def make_pte_value(pa):
  # 2MB frame number
  fn = pa >> 16
  val = fn << 12

  # 4KB frame number
  # fn = pa >> 12
  # val = fn << 8

  val |= 0x0600000000000001
  return val

# Takes 1. the path to the extracted page tables and 2. the hex of the virtual address
# Outputs: [PA of VA, PTE address, PTE entry content]
if __name__ == "__main__":
  parsed_data = retrieve_ptes(sys.argv[1])
  print(parsed_data[int(sys.argv[2], 16)])


