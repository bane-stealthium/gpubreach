#!/usr/bin/env bash
# parse_bitflips.sh
# Usage: ./parse_bitflips.sh [root_dir]
# Scans each subdirectory of root_dir for bit-flip log files and prints a summary table.

ROOT=$1

if [[ ! -d "$ROOT" ]]; then
    echo "Error: directory '$ROOT' not found." >&2
    exit 1
fi

# ── helpers ────────────────────────────────────────────────────────────────────

# Given a PTE bit index, compute the jump distance.
# Bit 17 → 2 MB; each additional bit doubles the distance.
pte_to_distance() {
    local bit=$1
    if (( bit < 17 )); then
        echo "< 2MB (bit ${bit})"
        return
    fi
    local exp=$(( bit - 17 ))          # 0-based exponent above 2 MB
    local base=2                        # 2 MB at bit 17
    local val=$(( base << exp ))        # 2 * 2^exp  MB
    if (( val >= 1024 )); then
        # Express in GB
        local gb_num=$(( val ))
        # Use awk for the division so we get a clean number
        awk -v v="$gb_num" 'BEGIN { printf "%gGB", v/1024 }'
    else
        echo "${val}MB"
    fi
}

# ── collect rows ───────────────────────────────────────────────────────────────

declare -a FOLDERS BYTES BYTE_GRAN BITS PTE_BITS DISTANCES

mapfile -t dirs < <(find "$ROOT" -mindepth 1 -maxdepth 1 -type d | sort)

for dir in "${dirs[@]}"; do
    folder=$(basename "$dir")

    # Search every file inside the subdirectory for the bit-flip pattern
    match=$(grep -rh "Observed.*bit-flip" "$dir" 2>/dev/null | head -1)

    if [[ -z "$match" ]]; then
        # Try alternate single-line format too
        match=$(grep -rh "bit.flip" "$dir" 2>/dev/null \
                | grep -i "byte" | head -1)
    fi

    if [[ -z "$match" ]]; then
        # No parseable flip found – record as N/A and continue
        FOLDERS+=("$folder")
        BYTES+=("N/A"); BYTE_GRAN+=("N/A"); BITS+=("N/A")
        PTE_BITS+=("N/A"); DISTANCES+=("N/A")
        continue
    fi

    # Extract Byte number  ── "Byte 34"
    byte=$(echo "$match" | grep -oP 'Byte\s+\K[0-9]+')

    # Extract bit position ── "The 6th bit" or "6th bit"
    bit_ordinal=$(echo "$match" | grep -oP '(\d+)(st|nd|rd|th)\s+bit' | grep -oP '^\d+')

    # If the above line is empty, try pulling from a separate line in the file
    if [[ -z "$bit_ordinal" ]]; then
        bit_ordinal=$(grep -rh "bit flipped" "$dir" 2>/dev/null \
                      | grep -oP '(\d+)(st|nd|rd|th)\s+bit' \
                      | grep -oP '^\d+' | head -1)
    fi

    if [[ -z "$byte" || -z "$bit_ordinal" ]]; then
        FOLDERS+=("$folder")
        BYTES+=("?"); BYTE_GRAN+=("?"); BITS+=("$bit_ordinal")
        PTE_BITS+=("?"); DISTANCES+=("?")
        continue
    fi

    byte_gran=$(( byte % 8 ))
    pte_bit=$(( byte_gran * 8 + bit_ordinal ))
    distance=$(pte_to_distance "$pte_bit")

    FOLDERS+=("$folder")
    BYTES+=("$byte")
    BYTE_GRAN+=("$byte_gran")
    BITS+=("$bit_ordinal")
    PTE_BITS+=("$pte_bit")
    DISTANCES+=("$distance")
done

# ── print table ────────────────────────────────────────────────────────────────

# Column widths (minimum values, will be widened by data if needed)
w_folder=8; w_byte=4; w_gran=12; w_bit=3; w_pte=7; w_dist=13

for i in "${!FOLDERS[@]}"; do
    (( ${#FOLDERS[$i]}   > w_folder )) && w_folder=${#FOLDERS[$i]}
    (( ${#BYTES[$i]}     > w_byte   )) && w_byte=${#BYTES[$i]}
    (( ${#BYTE_GRAN[$i]} > w_gran   )) && w_gran=${#BYTE_GRAN[$i]}
    (( ${#BITS[$i]}      > w_bit    )) && w_bit=${#BITS[$i]}
    (( ${#PTE_BITS[$i]}  > w_pte    )) && w_pte=${#PTE_BITS[$i]}
    (( ${#DISTANCES[$i]} > w_dist   )) && w_dist=${#DISTANCES[$i]}
done

sep_line() {
    printf "+-%-${w_folder}s-+-%-${w_byte}s-+-%-${w_gran}s-+-%-${w_bit}s-+-%-${w_pte}s-+-%-${w_dist}s-+\n" \
        "$(printf '%*s' $w_folder '' | tr ' ' '-')" \
        "$(printf '%*s' $w_byte   '' | tr ' ' '-')" \
        "$(printf '%*s' $w_gran   '' | tr ' ' '-')" \
        "$(printf '%*s' $w_bit    '' | tr ' ' '-')" \
        "$(printf '%*s' $w_pte    '' | tr ' ' '-')" \
        "$(printf '%*s' $w_dist   '' | tr ' ' '-')"
}

printf "\nBit-Flip Summary — root: %s\n\n" "$ROOT"
sep_line
printf "| %-${w_folder}s | %-${w_byte}s | %-${w_gran}s | %-${w_bit}s | %-${w_pte}s | %-${w_dist}s |\n" \
    "Folder" "Byte" "Byte (mod 8)" "Bit" "PTE Bit" "Jump Distance"
sep_line
for i in "${!FOLDERS[@]}"; do
    printf "| %-${w_folder}s | %-${w_byte}s | %-${w_gran}s | %-${w_bit}s | %-${w_pte}s | %-${w_dist}s |\n" \
        "${FOLDERS[$i]}" "${BYTES[$i]}" "${BYTE_GRAN[$i]}" \
        "${BITS[$i]}" "${PTE_BITS[$i]}" "${DISTANCES[$i]}"
done
sep_line
printf "\n"