#!/bin/bash
set -e

DEST_TEST_DIR=/opt/azurehpc/test

mkdir -p $DEST_TEST_DIR

cp $TEST_DIR/run-tests.sh $DEST_TEST_DIR

cp -r $TEST_DIR/health_checks $DEST_TEST_DIR

exit 0
