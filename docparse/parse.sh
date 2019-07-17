#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

cd ..

echo "{"

first=1

for test in `find testcases/ -name '*.c'`; do
	a=$(./docparse/docparse "$test")
	if [ -n "$a" ]; then
		if [ -z "$first" ]; then
			echo ','
		fi
		first=
		echo -n "$a"
	fi
done

echo
echo "}"
