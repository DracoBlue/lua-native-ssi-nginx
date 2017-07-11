#!/usr/bin/env bash

curl -v -sS curl -v -sS "localhost:4778/max-age/include-broken-max-age-value-and-expires-in-30.json" 2>&1 | grep "Cache-Control" | tr -d "\n"
exit $?