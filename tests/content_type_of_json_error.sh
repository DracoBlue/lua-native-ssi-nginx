#!/usr/bin/env bash

curl -v -sS "localhost:4779/bad-gateway/" 2>&1 | grep '< Content-Type' | tr -d "\n"
exit $?