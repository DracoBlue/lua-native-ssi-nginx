#!/usr/bin/env bash

curl -v -sS "localhost:4780/status401/" 2>&1 | grep '< HTTP' | tr -d "\n"
exit $?