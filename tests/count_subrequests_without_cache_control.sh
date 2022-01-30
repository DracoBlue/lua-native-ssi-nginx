#!/usr/bin/env bash

curl -v -sS -H 'X-Ssi-Debug: true' "http://localhost:4778/max-age/include-without-cache-control-expires-in-30.json" 2>&1 | grep "X-Ssi-Missing-Cache-Control" | sort -n | tr -d "\n"
exit $?