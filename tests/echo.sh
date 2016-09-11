#!/usr/bin/env bash

curl -sS -X POST -H "Content-Type: application/json" -d '{"key":"value"}' "localhost:4778/echo/"
exit $?