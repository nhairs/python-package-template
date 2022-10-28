### IMPORTS
### ============================================================================
## Standard Library
import datetime
import re

## Installed

## Application
from python_template import _version

### TESTS
### ============================================================================
def test_build_datetime_type():
    assert isinstance(_version.BUILD_DATETIME, datetime.datetime)
