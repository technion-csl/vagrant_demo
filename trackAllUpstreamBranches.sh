#! /bin/bash

upstream_branches=$(git branch -a | \grep upstream | \grep -v master | \grep -v HEAD)
for branch in $upstream_branches; do
    git branch --track ${branch#remotes/upstream/} $branch
done
