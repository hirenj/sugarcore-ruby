#!/bin/sh

for testfile in tests/tc_*.rb; do
	ruby -I lib $testfile
done
