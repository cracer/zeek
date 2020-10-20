#!/usr/bin/env bash
#
# On a Zeek build configured with --enable-coverage, this script
# produces a code coverage report in HTML format after Zeek has been invoked. The
# intended application of this script is after the btest testsuite has run.

# This depends on lcov to run.

function die {
    echo "$@"
    exit 1
}
function finish {
    rm -rf "$TMP"
}
function verify_run {
    if bash -c "$1" > /dev/null 2>&1; then
	echo ${2:-"ok"}
    else
	die ${3:-"error, abort"}
    fi
}
trap finish EXIT

HTML_REPORT=1
COVERALLS_API_KEY=""

function usage {
    usage="\
Usage: $0 <options>

  Generate coverage data for the Zeek code. This uses data generated during btest,
  so those should be run prior to calling this script. By default, this script
  generates an HTML report in the coverage-html directory in the root of the Zeek
  repo.

  Options:
    --help             Display this output.
    --coveralls KEY    Report coverage data to Coveralls.io using the specified
                       API key. Enabling this option disables the HTML report.
                       This option requires the coveralls-lcov Ruby gem to be
		       installed.
"

    echo "${usage}"
    exit 1
}

while (( "$#" )); do
    case "$1" in
	--coveralls)
	    HTML_REPORT=0
	    COVERALLS_API_KEY=$2
	    shift 2
	    ;;
	--help)
	    usage
	    shift 1
	    ;;
	*)
	    echo "Invalid option '$1'. Try $0 --help to see available options."
	    exit 1
	    ;;
    esac
done

TMP=".tmp.$$"
COVERAGE_FILE="./$TMP/coverage.info"
COVERAGE_HTML_DIR="${1:-"coverage-html"}"

# Files and directories that will be removed from the counts in step 5. Directories
# need to be surrounded by escaped wildcards.
REMOVE_TARGETS="*.yy *.ll *.y *.l \*/bro.dir/\* *.bif \*/zeek.dir/\* \*/rapidjson/\* \*/highwayhash/\* \*/caf/\* \*/src/3rdparty/\* \*/broker/3rdparty/\* \*/auxil/bifcl/\* \*/auxil/binpac/\*"

# 1. Move to base dir, create tmp dir
cd ../../;
mkdir "$TMP"

# 2. Check for .gcno and .gcda file presence
echo -n "Checking for coverage files... "
for pat in gcda gcno; do
    if [ -z "$(find . -name "*.$pat" 2>/dev/null)" ]; then
        echo "no .$pat files, nothing to do"
	exit 0
    fi
done
echo "ok"

# 3. If lcov does not exist, abort process.
echo -n "Checking for lcov... "
verify_run "which lcov" \
	"lcov installed on system, continue" \
	"lcov not installed, abort"

# 4. Create a "tracefile" through lcov, which is necessary to create html files later on.
echo -n "Creating tracefile for html generation... "
verify_run "lcov --no-external --capture --directory . --output-file $COVERAGE_FILE"

# 5. Remove a number of 3rdparty and "extra" files that shoudln't be included in the
# Zeek coverage numbers.
for TARGET in $REMOVE_TARGETS; do
    echo -n "Getting rid of $TARGET files from tracefile... "
    verify_run "lcov --remove $COVERAGE_FILE $TARGET --output-file $COVERAGE_FILE"
done

# 6. Create HTML files or Coveralls report
if [ $HTML_REPORT -eq 1 ]; then
    echo -n "Creating HTML files... "
    verify_run "genhtml -o $COVERAGE_HTML_DIR $COVERAGE_FILE"
else
    echo -n "Reporting to Coveralls..."
    verify_run "coveralls-lcov -t ${COVERALLS_API_KEY} ${COVERAGE_FILE}"
fi
