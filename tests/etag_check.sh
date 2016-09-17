#!/usr/bin/env bash

curl -v -sS -X POST -H "Content-Type: application/json" -d '{"key":"value"}' "localhost:4778/echo/" 2>&1 | grep '< ETag' | tr -d "\n"
exit $?