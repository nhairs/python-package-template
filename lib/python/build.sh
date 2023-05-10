#!/bin/bash

### FUNCTIONS
### ============================================================================
function replace_version_var {
    if [ $3 == 1 ]; then
        # Quotes
        sed -i "s/^${1} = .*/${1} = \"${2}\"/" "src/${PACKAGE_PYTHON_NAME}/_version.py"
    else
        # No Quotes
        sed -i "s/^${1} = .*/${1} = ${2}/" "src/${PACKAGE_PYTHON_NAME}/_version.py"
    fi
}

### MAIN
### ============================================================================
## Check constants set
## -----------------------------------------------------------------------------
echo "PACKAGE_NAME=${PACKAGE_NAME}"
echo "PACKAGE_PYTHON_NAME=${PACKAGE_PYTHON_NAME}"
echo "PACKAGE_VERSION=${PACKAGE_VERSION}"
echo "GIT_COMMIT_SHORT=${GIT_COMMIT_SHORT}"
echo "GIT_COMMIT=${GIT_COMMIT}"
echo "GIT_BRANCH=${GIT_BRANCH}"
echo "PYTHON_PACKAGE_REPOSITORY=${PYTHON_PACKAGE_REPOSITORY}"
echo "TESTPYPI_USERNAME=${TESTPYPI_USERNAME}"
echo "SOURCE_UID=${SOURCE_UID}"
echo "SOURCE_GID=${SOURCE_GID}"
echo "BUILD_TIMESTAMP=${BUILD_TIMESTAMP}"
echo "BUILD_VERSION=${BUILD_VERSION}"
# TODO


## Update _version.py
## -----------------------------------------------------------------------------
replace_version_var PACKAGE_VERSION "${PACKAGE_VERSION}" 1
replace_version_var BUILD_VERSION "${BUILD_VERSION}" 1
replace_version_var BUILD_GIT_HASH "${GIT_COMMIT}" 1
replace_version_var BUILD_GIT_HASH_SHORT "${GIT_COMMIT_SHORT}" 1
replace_version_var BUILD_GIT_BRANCH "${GIT_BRANCH}" 1
replace_version_var BUILD_TIMESTAMP "${BUILD_TIMESTAMP}" 0

echo "[computed _version.py]"
#head -n 22 "src/${PACKAGE_PYTHON_NAME}/_version.py" | tail -n 7
cat "src/${PACKAGE_PYTHON_NAME}/_version.py"


if [ "$PYTHON_PACKAGE_REPOSITORY" == "testpypi" ]; then
    echo "MODIFYING PACKAGE_NAME"
    # Replace name suitable for test.pypi.org
    # https://packaging.python.org/tutorials/packaging-projects/#creating-setup-py
    toml set --toml-path=pyproject.toml project.name "${PACKAGE_NAME}-${TESTPYPI_USERNAME}"
    mv "src/${PACKAGE_PYTHON_NAME}" "src/${PACKAGE_PYTHON_NAME}_$(echo -n $TESTPYPI_USERNAME | tr '-' '_')"
fi

if [[ "$GIT_BRANCH" != "master" && "$GIT_BRANCH" != "main" ]]; then
    toml set --toml-path=pyproject.toml project.version "${BUILD_VERSION}"
fi

## Build
## -----------------------------------------------------------------------------
#python3 setup.py bdist_wheel
python3 -m build --wheel
