#!/bin/sh

perl -pe 's/^.*?:Page /Page /' "$@" | grep '^Page ' |perl -pe 's/^Page [0-9.]+ (.*?): .*$/$1/'|uniq
