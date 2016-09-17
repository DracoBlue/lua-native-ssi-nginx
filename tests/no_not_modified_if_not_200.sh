#!/usr/bin/env bash

curl -v -sS -H 'If-None-Match: "85b2aa98e0ce60179785e8a292d6166e"' "localhost:4778/no_not_modified_if_not_200/" 2>&1 | grep '< HTTP/1.1' | tr -d "\n"
exit $?