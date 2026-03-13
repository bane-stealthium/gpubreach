#!/bin/sh

nohup $DUMP_ROOT/dumper/dumper -d 0 -s 0 -b $((512 * (2 ** 20))) -o $DUMP_ROOT/extractor/xyz && $DUMP_ROOT/extractor/extractor $DUMP_ROOT/extractor/xyz > ./dump.txt
