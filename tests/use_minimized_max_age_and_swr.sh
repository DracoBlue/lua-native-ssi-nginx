#!/usr/bin/env bash


curl -v -sS curl -v -sS "localhost:4778/max-age/includes-30-max-age-25-age-40-swr-expires-in-120.json" 
curl -v -sS curl -v -sS "localhost:4778/max-age/includes-30-max-age-25-age-40-swr-expires-in-120.json" 2>&1 | grep "Cache-Control" | tr -d "\n"
exit $?
