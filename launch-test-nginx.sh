#!/usr/bin/env bash
DOCKER_ARGS="--rm"
if [ "$1" == "daemon" ]
then
	DOCKER_ARGS="-d"
fi

if [ "$2" == "" ]
then
  cp .travis/Dockerfile .
else
  echo "FROM dracoblue/nginx-extras:$2" > Dockerfile
  cat .travis/Dockerfile | grep -v "^FROM " >> Dockerfile
fi

docker build -t lua-native-ss-nginx . && docker run $DOCKER_ARGS -p127.0.0.1:4777:4777 -p127.0.0.1:4778:4778 -p127.0.0.1:4779:4779 -p127.0.0.1:4780:4780 -p127.0.0.1:4781:4781 -it lua-native-ss-nginx
exit $?
