#!/bin/sh

#perl -pe 's/^.*?:Page /Page /' "$@" | egrep '^Page [0-9.]+ .*:' |perl -pe 's/^Page [0-9.]+ (.*?): .*$/$1/'|uniq
egrep '^Page [0-9.]+ .*:' "$@" |perl -pe 's/^Page [0-9.]+ (.*?): .*$/$1/'|uniq
