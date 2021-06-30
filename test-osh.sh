#! /bin/bash

cp _build/default/osh.exe osh

if ! [[ -x osh ]]; then
    echo "osh executable does not exist"
    exit 1
fi

./run-tests.sh $*
