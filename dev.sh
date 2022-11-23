#!/bin/bash

# Notes:
# - use shellcheck for bash linter (https://github.com/koalaman/shellcheck)

### SETUP
### ============================================================================
set -e  # Bail at the first sign of trouble

# Notation Reference: https://unix.stackexchange.com/questions/122845/using-a-b-for-variable-assignment-in-scripts#comment685330_122848
: ${DEBUG:=0}
: ${CI:=0}  # Flag for if we are in CI - default to not.

### CONTANTS
### ============================================================================
SOURCE_UID=$(id -u)
SOURCE_GID=$(id -g)
SOURCE_UID_GID="${SOURCE_UID}:${SOURCE_GID}"
GIT_COMMIT_SHORT=$(git rev-parse --short HEAD)
GIT_COMMIT=$(git rev-parse HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
PACKAGE_NAME=$(grep 'PACKAGE_NAME =' setup.py | cut -d '=' -f 2 | tr -d ' ' | tr -d '"')
PACKAGE_PYTHON_NAME=$(echo -n "$PACKAGE_NAME" | tr '-' '_')
PACKAGE_VERSION=$(grep '^PACKAGE_VERSION' setup.py | cut -d '"' -f 2)

: ${AUTOCLEAN_LIMIT:=10}

: ${PYTHON_PACKAGE_REPOSITORY:="pypi"}
: ${TESTPYPI_USERNAME="$USER-test"}

## Build related
BUILD_TIMESTAMP=$(date +%s)

if [[ "$GIT_BRANCH" == "master" || "$GIT_BRANCH" == "main" ]]; then
    BUILD_VERSION="${PACKAGE_VERSION}"
else
    # Tox doesn't like version labes like
    # python_template-0.0.0+3f2d02f.1667158525-py3-none-any.whl
    #BUILD_VERSION="${PACKAGE_VERSION}+${GIT_COMMIT_SHORT}.${BUILD_TIMESTAMP}"

    # Use PEP 440 non-compliant versions since we know it works
    BUILD_VERSION="${PACKAGE_VERSION}.${GIT_COMMIT_SHORT}"
fi

## Insert into .tmp/env
## -----------------------------------------------------------------------------
if [ ! -d .tmp ]; then
    mkdir .tmp
fi

echo "⚙️  writing .tmp/env"
cat > .tmp/env <<EOF
PACKAGE_NAME=${PACKAGE_NAME}
PACKAGE_PYTHON_NAME=${PACKAGE_PYTHON_NAME}
PACKAGE_VERSION=${PACKAGE_VERSION}
GIT_COMMIT_SHORT=${GIT_COMMIT_SHORT}
GIT_COMMIT=${GIT_COMMIT}
GIT_BRANCH=${GIT_BRANCH}
PYTHON_PACKAGE_REPOSITORY=${PYTHON_PACKAGE_REPOSITORY}
TESTPYPI_USERNAME=${TESTPYPI_USERNAME}
SOURCE_UID=${SOURCE_UID}
SOURCE_GID=${SOURCE_GID}
SOURCE_UID_GID=${SOURCE_UID_GID}
BUILD_TIMESTAMP=${BUILD_TIMESTAMP}
BUILD_VERSION=${BUILD_VERSION}
BUILD_DIR=.tmp/dist  # default
EOF

# workaround for old docker-compose versions
cp .tmp/env .env

### FUNCTIONS
### ============================================================================
## Docker Functions
## -----------------------------------------------------------------------------
function compose_build {
    heading2 "🐋 Building $1"
    if [ "$DEBUG" = 1 ]; then
        docker-compose build $1
    else
        docker-compose build $1 1>/dev/null
    fi
    echo
}

function compose_run {
    heading2 "🐋 running $@"
    docker-compose -f docker-compose.yml run --rm $@
    echo
}

function docker_clean {
    heading2 "🐋 Removing ${PACKAGE_NAME} images"
    COUNT_IMAGES=$(docker images | grep "$PACKAGE_NAME" | wc -l)
    if [[ $COUNT_IMAGES -gt 0 ]]; then
        docker images | grep "$PACKAGE_NAME" | awk '{OFS=":"} {print $1, $2}' | xargs docker rmi
    fi
}


function docker_clean_unused {
    docker images | \
        grep "$PACKAGE_NAME" | \
        grep -v "$GIT_COMMIT" | \
        awk '{OFS=":"} {print $1, $2}' | \
        xargs docker rmi
}

function docker_autoclean {
    if [[ $CI = 0 ]]; then
        COUNT_IMAGES=$(docker images | grep "$PACKAGE_NAME" | grep -v "$GIT_COMMIT" | wc -l)
        if [[ $COUNT_IMAGES -gt $AUTOCLEAN_LIMIT ]]; then
            heading2 "Removing unused ${PACKAGE_NAME} images 🐋"
            docker_clean_unused
        fi
    fi
}

## Utility
## -----------------------------------------------------------------------------
function heading {
    # Print a pretty heading
    # https://en.wikipedia.org/wiki/Box-drawing_character#Unicode
    echo "╓─────────────────────────────────────────────────────────────────────"
    echo "║ $@"
    echo "╙───────────────────"
    echo
}

function heading2 {
    # Print a pretty heading-2
    # https://en.wikipedia.org/wiki/Box-drawing_character#Unicode
    echo "╓ $@"
    echo "╙───────────────────"
}

## Debug Functions
## -----------------------------------------------------------------------------
function check_file {
    # Pretty print if a file exists or not.
    if [[ -f "$1" ]]; then
        echo -e "$1 \e[1;32m EXISTS\e[0m"
    else
        echo -e "$1 \e[1;31m MISSING\e[0m"
    fi
}

## Command Functions
## -----------------------------------------------------------------------------
function command_build {
    if [ -z $1 ] | [ "$1" = "dist" ]; then
        BUILD_DIR="dist"
    elif [ "$1" = "tmp" ]; then
        BUILD_DIR=".tmp/dist"
    else
        return 1
    fi

    # TODO: unstashed changed guard

    if [ ! -d $BUILD_DIR ]; then
        heading "setup 📜"
        mkdir $BUILD_DIR
    fi

    echo "BUILD_DIR=${BUILD_DIR}" >> .env
    echo "BUILD_DIR=${BUILD_DIR}" >> .tmp/env

    heading "build 🐍"
    compose_build python-build
    compose_run python-build
}

### MAIN
### ============================================================================
case $1 in

    "format")
        if [[ $CI -gt 0 ]]; then
            echo "ERROR! Do not run format in CI!"
            exit 250
        fi
        heading "black 🐍"
        compose_build python-common
        compose_run python-common \
            black --line-length 100 --target-version py37 setup.py src tests
        ;;

    "lint")
        compose_build python-common

        if [ "$DEBUG" = 1 ]; then
            heading2 "🤔 Debugging"
            compose_run python-common ls -lah
            compose_run python-common pip list
        fi

        heading "black - check only 🐍"
        compose_run python-common \
            black --line-length 100 --target-version py37 --check --diff setup.py src tests

        heading "pylint 🐍"
        compose_run python-common pylint --output-format=colorized setup.py src tests

        heading "mypy 🐍"
        compose_run python-common mypy src tests
        ;;

    "test")
        command_build tmp

        heading "tox 🐍"
        compose_build python-tox
        compose_run python-tox tox -e py37

        rm -rf .tmp/dist/*
        ;;

    "test-full")
        command_build tmp

        heading "tox 🐍"
        compose_build python-tox
        compose_run python-tox tox

        rm -rf .tmp/dist/*
        ;;

    "build")
        command_build dist
        ;;

    "upload")
        heading "Upload to ${PYTHON_PACKAGE_REPOSITORY}"
        heading "setup 📜"
        if [[ -z $(pip3 list | grep keyrings.alt) ]]; then
            pip3 install --user keyrings.alt
            pip3 install --user twine
        fi

        if [ ! -d dist_uploaded ]; then
            mkdir dist_uploaded
        fi

        heading "upload 📜"
        twine upload --repository "${PYTHON_PACKAGE_REPOSITORY}" dist/*.whl

        echo "📜 cleanup"
        mv dist/* dist_uploaded
        ;;

    "repl")
        heading "REPL 🐍"
        if [[ -f "repl.py" ]]; then
            echo "Using provided repl.py"
            echo
            cp repl.py > .tmp/repl.py
        else
            echo "Using default repl.py"
            echo
            cat > .tmp/repl.py <<EOF
import ${PACKAGE_PYTHON_NAME}
print('Your package is already imported 🎉\nPress ctrl+d to exit')
EOF
        fi

        compose_build python-common
        compose_run python-common bpython --config bpython.ini -i .tmp/repl.py
        ;;

    "run")
        heading "Running File 🐍"
        compose_build python-common
        compose_run python-common python3 "${2}"
        ;;


    "docs")
        heading "Preview Docs 🐍"
        compose_build python-common
        compose_run -p 127.0.0.1:8080:8080 python-common mkdocs serve -a 0.0.0.0:8080 -w docs
        ;;

    #"web")
        #heading "Running Development Server 🐍"
        #compose_build python-common
        #compose_run -p 127.0.0.1:8000:8080 python-common \
            #uvicorn --host 0.0.0.0 --port 8080 \
            #--factory product_data.rest_api.app:create_app --reload

        #;;

    "clean")
        heading "Cleaning 📜"
        docker_clean

        echo "🐍 pyclean"
        pyclean src
        pyclean tests

        echo "🐍 remove build artifacts"
        rm -rf build dist "src/${PACKAGE_PYTHON_NAME}.egg-info"

        echo "cleaning .tmp"
        rm -rf .tmp/*
        ;;

    "debug")
        heading "Debug 📜"
        cat .tmp/env
        echo
        echo "Checking Directory Layout..."
        check_file "src/${PACKAGE_PYTHON_NAME}/__init__.py"
        check_file "src/${PACKAGE_PYTHON_NAME}/_version.py"

        echo
        ;;

    "help")
        echo "dev.sh - development utility"
        echo "Usage: ./dev.sh COMMAND"
        echo
        echo "    build    Build python packages"
        echo "    clean    Cleanup clutter"
        echo "    debug    Display debug / basic health check information"
        echo "   format    Format files"
        echo "     help    Show this text"
        echo "     lint    Lint files. You probably want to format first."
        echo "   upload    Upload built files to where they are distributed from (e.g. PyPI)"
        echo "     repl    Open Python interactive shell with the package imported"
        echo "     test    Run unit tests"
        echo "test-full    Run unit tests on all python versions"
        echo "     docs    Preview docs locally"
        echo
        echo ""

        ;;

    *)
        echo -e "\e[1;31mUnknown command \"${1}\"\e[0m"
        exit 255
        ;;
esac

docker_autoclean
