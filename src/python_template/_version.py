"""Version information for this package."""
### IMPORTS
### ============================================================================
## Standard Library
import datetime

## Installed

## Application

### CONSTANTS
### ============================================================================
## Version Information - DO NOT EDIT
## -----------------------------------------------------------------------------
# These variables will be set during the build process. Do not attempt to edit.
PACKAGE_VERSION = ""
BUILD_VERSION = ""
BUILD_GIT_HASH = ""
BUILD_GIT_HASH_SHORT = ""
BUILD_GIT_BRANCH = ""
BUILD_TIMESTAMP = 0
BUILD_DATETIME = datetime.datetime.utcfromtimestamp(BUILD_TIMESTAMP)

## Version Information Templates
## -----------------------------------------------------------------------------
# You can customise the templates used for version information here.
VERSION_INFO_SHORT = f"{BUILD_VERSION}"
VERSION_INFO = f"{BUILD_VERSION}@{BUILD_GIT_HASH_SHORT}"
VERSION_INFO_LONG = f"{BUILD_VERSION} ({BUILD_GIT_BRANCH}@{BUILD_GIT_HASH_SHORT})"
VERSION_INFO_FULL = (
    f"{PACKAGE_VERSION} ({BUILD_VERSION})\n"
    f"{BUILD_GIT_BRANCH}@{BUILD_GIT_HASH}\n"
    f"Built: {BUILD_DATETIME}"
)
