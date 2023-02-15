#!/bin/bash

# MIT License
#
# Copyright (c) 2023 Davidson Francis <davidsondfgl@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Default amount of bytes to dump
DUMP_BYTES=32

# Help function
show_help() {
    echo "Usage: $0 [-h] [-d <bytes>] <input_file>"
    echo "  -h               Display this help message"
    echo "  -d <bytes>       Amount of bytes to dump (default is $DUMP_BYTES)"
    echo "  input_file       Input file name"
    echo ""
    echo "Please note that amount of bytes to dump is only as estimation"
    echo "and the final instructions of the dump might be wrongly"
    echo "disassembled! To ensure the right dissassembling, adjust the"
    echo "'-d' parameter accordingly to your expectations."
    exit 0
}

# Parse parameters
while getopts "hd:" opt; do
    case $opt in
        h) show_help ;;
        d) DUMP_BYTES="$OPTARG" ;;
        ?) show_help ;;
    esac
done
shift $((OPTIND - 1))

# Check if input file exists
if [ ! -f "$1" ]; then
    echo "Error: Input file not found"
    show_help
fi

# Generate assembly code from input file
input="[BITS 16]\n"
while read line; do
    input="$input\n$line"
done

printf "$input" > ".temp.asm"
nasm -fbin .temp.asm -o .temp.bin

# Get hex escaped string
esc=$(xxd -p .temp.bin | tr -d '\n' | sed 's/../\\x&/g')

# Get occurrences and dump instructions
LANG=C grep -PaUbo "$esc" "$1" | while read line; do
    offset=$(echo "$line" | cut -d: -f1)
    echo "Offset $offset:"
    dd if="$1" bs=1 skip=$offset count=$DUMP_BYTES 2>/dev/null | ndisasm -b16 -
done

rm -rf .temp.{asm,bin} 2>/dev/null
