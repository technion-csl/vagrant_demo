#! /bin/bash

upstream_branches=$(git branch -a | \grep upstream | \grep -v master | \grep -v HEAD)
for branch in $upstream_branches; do
    #echo $branch
    #echo ${branch#remotes/upstream/}
    git branch --track ${branch#remotes/upstream/} $branch
done
