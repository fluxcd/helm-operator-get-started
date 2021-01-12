#!/usr/bin/env bash

repository="kkakol/demoapp"
branch="master"
version="${1:-1.0.0}"

commit=$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1 | awk '{print tolower($0)}')

if [ -z "${version}" ]; then
    image="${repository}:${version}" #${branch}-${commit}"
else
    image="${repository}:${version}"
fi

echo ">>>> Building image ${image} <<<<"

docker build -t ${image} -f Dockerfile .

docker push ${image}
