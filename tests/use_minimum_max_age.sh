#!/usr/bin/env bash

curl -v -sS curl -v -sS "localhost:4778/max-age/include-age-5-and-cache-control-10-and-15-expires-in-30.json" 2>&1 | grep "Cache-Control" | tr -d "\n"
exit $?