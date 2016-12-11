#!/bin/sh

git filter-branch -f --env-filter '

an="$GIT_AUTHOR_NAME"
am="$GIT_AUTHOR_EMAIL"
cn="$GIT_COMMITTER_NAME"
cm="$GIT_COMMITTER_EMAIL"

if [ "$GIT_AUTHOR_NAME" = "BuildTools" ]
then
    cn="Noah Santschi-Cooney"
    cm="noah@santschi-cooney.ch"
    an="Noah Santschi-Cooney"
    am="noah@santschi-cooney"
fi
if [ "$GIT_AUTHOR_NAME" = "BuildTools" ]
then
    cn="Noah Santschi-Cooney"
    cm="noah@santschi-cooney"
    an="Noah Santschi-Cooney"
    am="noah@santschi-cooney"
fi

export GIT_AUTHOR_NAME="$an"
export GIT_AUTHOR_EMAIL="$am"
export GIT_COMMITTER_NAME="$cn"
export GIT_COMMITTER_EMAIL="$cm"
'