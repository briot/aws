#! /bin/sh
#
# Usage: Put both distrib tarball (aws-$version.tar.gz and
# aws-http-$version.tar.gz) into a directory and launch the script by passing
# the AWS version as parameter.
# This script will unpack the tarball, build both distribs and install them.
#
# Note that it is necessary to setup properly XMLADA and ASIS below.

XMLADA=/opt/xmlada
ASIS=/opt/gnatpro/5.01a/lib/asis

if [ "$1" == "" ]; then
    echo "Usage: test-distrib <version>";
    exit 1;
fi

version=$1

std=aws-$version.tar.gz
http=aws-http-$version.tar.gz
root=`pwd`

echo Test $std
mkdir std-$version
cd std-$version
tar xfz ../$std
cd aws*
export ADA_PROJECT_PATH=`pwd`/.build/projects\;$XMLADA/projects
make XMLADA=true ASIS=$ASIS setup build
make XMLADA=true ASIS=$ASIS INSTALL=$root/std-$version install
cd ../..

echo Test $http
mkdir http-$version
cd http-$version
tar xfz ../$http
cd aws*
export ADA_PROJECT_PATH=`pwd`/.build/projects
make setup build
make INSTALL=$root/http-$version install