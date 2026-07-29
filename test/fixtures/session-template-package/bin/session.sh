#!/bin/sh
printf 'workspace-template-ready\n'
while IFS= read -r line; do
  printf 'workspace-template:%s\n' "$line"
done
