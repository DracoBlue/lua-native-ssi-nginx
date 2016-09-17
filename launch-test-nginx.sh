#!/usr/bin/env bash
DOCKER_ARGS="--rm"
if [ "$1" == "daemon" ]
then
	DOCKER_ARGS="-d"
fi

cp .travis/Dockerfile . && docker build -t lua-native-ss-nginx . && docker run $DOCKER_ARGS -p127.0.0.1:4777:4777 -p127.0.0.1:4778:4778 -p127.0.0.1:4779:4779 -p127.0.0.1:4780:80 -it lua-native-ss-nginx
exit $?