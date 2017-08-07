#!/usr/bin/env bash

curl -v -sS "http://localhost:4781/max-age/include-stale-expires-in-120.json" 2>&1 | grep "Cache-Control" | tr -d "\n"
exit $?