#!/usr/bin/env bash

repository="stefanprodan/podinfo"
branch="master"
version="0.4.0"
commit=$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1 | awk '{print tolower($0)}')

while getopts :r:b:v: o; do
    case "${o}" in
        r)
            repository=${OPTARG}
            ;;
        b)
            branch=${OPTARG}
            ;;
        v)
            version=${OPTARG}
            ;;
    esac
done
shift $((OPTIND-1))

image="${repository}:${branch}-${commit}"

echo ">>>> Building image ${image} <<<<"

docker build --build-arg GITCOMMIT=${commit} --build-arg VERSION=${version} -t ${image} -f Dockerfile.ci .
