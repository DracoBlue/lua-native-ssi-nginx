#!/usr/bin/env bash

curl -v http://localhost:4778/max-age/30-seconds/35-age/40-swr
curl -v http://localhost:4777/max-age/30-seconds/35-age/40-swr


curl -v -sS "localhost:4777/max-age/includes-30-max-age-35-age-40-swr-expires-in-120.json" 
curl -v -sS "localhost:4778/max-age/includes-30-max-age-35-age-40-swr-expires-in-120.json" 
curl -v -sS "localhost:4778/max-age/includes-30-max-age-35-age-40-swr-expires-in-120.json" 2>&1 | grep "Cache-Control" | tr -d "\n"
exit $?
