#!/bin/bash

if [ -z "$1" ]; then
    echo "You must provide a target directory"
    exit 1
fi

TARGET=$1

echo "Copying into ${TARGET}"

FILES_TO_COPY="\
    bpython.ini \
    dev.sh \
    docker-compose.yml \
    .dockerignore \
    .gitignore \
    lib \
    LICENCE \
    MANIFEST.in \
    mypy.ini \
    pylintrc \
    pyproject.toml \
    src \
    tests \
    tox.ini \
    "

for FILE in $FILES_TO_COPY; do
    echo "Copying ${FILE}"
    cp -r "${FILE}" "${TARGET}/"
done

echo "Writing ${TARGET}/NOTICE"
cat > "${TARGET}/NOTICE" << EOF
This software includes the following licenced software:
  - python-package-template
    Copyright (c) 2020 Nicholas Hairs
    Licenced under The MIT Licence
    Source: https://github.com/nhairs/python-package-template

EOF
