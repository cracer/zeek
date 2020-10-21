#! /usr/bin/env bash

# The ZEEK_COVERALLS_REPO_TOKEN environment variable must exist
# for this script to work correctly. On Cirrus, this is provided
# via the secured variables.

cd testing/coverage
make coverage
make coveralls
