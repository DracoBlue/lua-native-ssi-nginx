#!/usr/bin/env bash

curl -v -sS curl -v -sS "localhost:4778/max-age/broken-max-age-value" 2>&1 | grep "Cache-Control" | grep -v 'Missing' | tr -d "\n"
exit $?