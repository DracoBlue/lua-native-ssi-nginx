#!/usr/bin/env bash

curl -v -sS -H 'X-Ssi-Debug: true' "http://localhost:4778/json/" 2>&1 | grep "X-Ssi-Minimize-MaxAge" | sort -n | tr -d "\n"
exit $?