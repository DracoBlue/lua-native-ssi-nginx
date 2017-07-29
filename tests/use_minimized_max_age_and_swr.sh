#!/usr/bin/env bash

curl -v http://localhost:4778/max-age/35-seconds/30-age/40-swr
curl -v http://localhost:4777/max-age/35-seconds/30-age/40-swr

curl -v -sS "http://localhost:4778/max-age/include-age-5-and-cache-control-10-and-15-expires-in-30.json"


curl -v -sS "http://localhost:4777/max-age/include-age-5-and-cache-control-10-and-15-expires-in-30.json"

curl -v -sS "http://localhost:4777/max-age/include-stale-expires-in-120.json" 
curl -v -sS "http://localhost:4778/max-age/include-stale-expires-in-120.json" 
curl -v -sS "http://localhost:4778/max-age/include-stale-expires-in-120.json" 2>&1 | grep "Cache-Control" | tr -d "\n"
exit $?
