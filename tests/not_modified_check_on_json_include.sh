#!/usr/bin/env bash

curl -v -sS -H 'If-None-Match: "8cb1ed23ce8bcf345b3f285045d9a9ba"' "localhost:4778/json_include/" 2>&1 | grep '< HTTP/1.1' | tr -d "\n"
exit $?