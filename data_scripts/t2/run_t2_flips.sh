# Variables
num_agg=24
num_warp=8
num_thread=3
round=1

row_step=4
skip_step=4
count_iter=10

# Constant values
addr_step=256
iterations=46000
mem_size=50465865728
num_rows=64100

# banks=(256 2048 2048 2048 5120 6400 6400 6400)
banks=(A B C C D E F F F)
flips=(30016 13057 8421 57485 52963 13522 47649 29140 41740)
delays=(55 58 57 57 57 59 59 59 59)
vic_pos=(4 6 4 2 4 4 0 1 7)
vic_num=(1 0 0 0 0 0 0 0 0)
flip_names=(A1 B1 C1 C2 D1 E1 F1 F2 F3)

# pats=(00 11 22 33 44 55 66 77 88 99 aa bb cc dd ee ff)
pats=(55 aa)

dirname=$HAMMER_ROOT/results/sample_bitflips

for i in {1..8}; do
    
    bank_id=${banks[$i]}
    flip_row=${flips[$i]}
    delay=${delays[$i]}
    flip_name=${flip_names[$i]}

    min_rowid=$((flip_row + 2))
    max_rowid=$((flip_row + 92))

    mkdir -p $dirname/$flip_name

    echo "Start hammering bank $bank_id row $flip_row"

    for j in {0..1}; do

        k=$((1-j))
        vic_pat=0x${pats[$j]}
        agg_pat=0x${pats[$k]}

        expected=$(( (vic_pat >> vic_pos[i]) & 1 ))
        if [ $expected -ne ${vic_num[$i]} ]; then
            # echo "- Skip   Victim: $vic_pat"
            continue
        fi

        # File paths
        rowset_file="$HAMMER_ROOT/results/row_sets/ROW_SET_${bank_id}.txt"
        log_file="$dirname/$flip_name/${num_agg}agg_b${bank_id}_flip${flip_row}_${pats[$j]}${pats[$k]}.log"
        bitflip_file="$dirname/$flip_name/${num_agg}agg_b${bank_id}_count_flip${flip_row}_${pats[$j]}${pats[$k]}.txt"

        echo "- Victim Pattern: $vic_pat, Aggressor Pattern: $agg_pat"

        $HAMMER_ROOT/src/out/build/gpu_hammer $rowset_file $((num_agg - 1)) $addr_step $iterations $min_rowid $max_rowid $row_step $skip_step $mem_size $num_warp $num_thread $delay $round $count_iter $num_rows $vic_pat $agg_pat $bitflip_file > $log_file

        sleep 3

    done

done