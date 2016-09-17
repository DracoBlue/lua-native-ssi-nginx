#!/usr/bin/env bash

curl -v -sS "localhost:4778/status500/" 2>&1 | grep '< HTTP' | tr -d "\n"
exit $?