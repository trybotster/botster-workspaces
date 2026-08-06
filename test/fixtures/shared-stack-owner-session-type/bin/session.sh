#!/bin/sh
printf 'shared-stack-owner-ready\n'
while IFS= read -r line; do
  printf 'shared-stack-owner:%s\n' "$line"
done
