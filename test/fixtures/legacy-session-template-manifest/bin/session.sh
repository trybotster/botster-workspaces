#!/bin/sh
printf 'legacy-manifest-ready\n'
while IFS= read -r line; do
  printf 'legacy-manifest:%s\n' "$line"
done
