#!/bin/bash

if [ -z "$1" ]; then
    echo "must provide target dir"
    exit 1
fi

TARGET=$1

echo "Copying into ${TARGET}"

FILES_TO_COPY="dev.sh .dockerignore .gitignore lib pylintrc setup.py src tests"

for FILE in $FILES_TO_COPY; do
    cp -r "${FILE}" "${TARGET}/"
done
