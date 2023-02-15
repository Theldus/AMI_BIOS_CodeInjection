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

# Default threshold value
THRESHOLD=8

# Help function
show_help() {
	echo "Usage: $0 [-h] [-t <threshold>] <input_file>"
	echo "  -h              Display this help message"
	echo "  -t <threshold>  Set the threshold value (default is $THRESHOLD)"
	echo "  input_file      Input file name"
	exit 0
}

# Parse parameters
while getopts "ht:" opt; do
	case $opt in
		h) show_help ;;
		t) THRESHOLD="$OPTARG" ;;
		?) show_help ;;
	esac
done
shift $((OPTIND - 1))

# Check if input file exists
if [ ! -f "$1" ]; then
	echo "Error: Input file not found"
	show_help
fi

input_file="$1"
output_file="$(basename "$input_file").dump"

# Generate skips string
strings=$(strings "$input_file" -n"$THRESHOLD" -td)
skips=""
while IFS= read -r line; do
	offset=$(echo "$line" | awk '{print $1}')
	string=$(echo "$line" | awk '{print substr($0, index($0, $2))}')
	length=${#string}
	skips="$skips -k$offset,$length"
done <<< "$strings"

# Generate output file
ndisasm -b16 "$input_file" $skips > "$output_file"
echo "Output file: $output_file"
