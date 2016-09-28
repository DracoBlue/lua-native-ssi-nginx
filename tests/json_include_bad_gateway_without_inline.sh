#!/usr/bin/env bash

curl -sS "localhost:4779/json_include_bad_gateway/"
exit $?