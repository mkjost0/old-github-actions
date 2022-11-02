#!/bin/sh -l

echo "Hello! $1"
time=$(date)
# echo "time=$time" >> $GITHUB_OUTPUT
if [ -f /.dockerenv ]; then
    echo "I'm inside matrix ;(";
else
    echo "I'm living in real world!";
fi
