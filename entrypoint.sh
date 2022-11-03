#!/bin/sh -l

echo "Hello! $1"
time=$(date)
# echo "time=$time" >> $GITHUB_OUTPUT
pwd
ls
echo "hehe"
cd tests
scons build/ALL/gem5.opt -j 24
./main.py run gem5/x86-boot-tests -j24 --skip-build
