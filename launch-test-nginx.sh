#!/usr/bin/env bash
cp .travis/Dockerfile . && docker build -t lua-native-ss-nginx . && docker run --rm -p127.0.0.1:4777:4777 -p127.0.0.1:4778:4778 -p127.0.0.1:4780:80 -it lua-native-ss-nginx
exit $?