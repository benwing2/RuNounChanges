#!/bin/sh

perl -pe 's/\n/,/;' |perl -pe 's/,$//;' -e 's/Category://g;'
