#!/bin/bash

# Copy a folder from one git repo to another git repo,
# preserving full history of the folder.

SRC_GIT_REPO='/d/git-experimental/your-old-webapp'
DST_GIT_REPO='/d/git-experimental/your-new-webapp'
SRC_BRANCH_NAME='master'
DST_BRANCH_NAME='import-stuff-from-old-webapp'
# Most likely you want the REWRITE_FROM and REWRITE_TO to have a trailing slash!
REWRITE_FROM='app/src/main/static/'
REWRITE_TO='app/src/main/static/'

verifyPreconditions() {
    #echo 'Checking if SRC_GIT_REPO is a git repo...' &&
      { test -d "${SRC_GIT_REPO}/.git" || { echo "Fatal: SRC_GIT_REPO is not a git repo"; exit; } } &&
    #echo 'Checking if DST_GIT_REPO is a git repo...' &&
      { test -d "${DST_GIT_REPO}/.git" || { echo "Fatal: DST_GIT_REPO is not a git repo"; exit; } } &&
    #echo 'Checking if REWRITE_FROM is not empty...' &&
      { test -n "${REWRITE_FROM}" || { echo "Fatal: REWRITE_FROM is empty"; exit; } } &&
    #echo 'Checking if REWRITE_TO is not empty...' &&
      { test -n "${REWRITE_TO}" || { echo "Fatal: REWRITE_TO is empty"; exit; } } &&
    #echo 'Checking if REWRITE_FROM folder exists in SRC_GIT_REPO' &&
      { test -d "${SRC_GIT_REPO}/${REWRITE_FROM}" || { echo "Fatal: REWRITE_FROM does not exist inside SRC_GIT_REPO"; exit; } } &&
    #echo 'Checking if SRC_GIT_REPO has a branch SRC_BRANCH_NAME' &&
      { cd "${SRC_GIT_REPO}"; git rev-parse --verify "${SRC_BRANCH_NAME}" || { echo "Fatal: SRC_BRANCH_NAME does not exist inside SRC_GIT_REPO"; exit; } } &&
    #echo 'Checking if DST_GIT_REPO has a branch DST_BRANCH_NAME' &&
      { cd "${DST_GIT_REPO}"; git rev-parse --verify "${DST_BRANCH_NAME}" || { echo "Fatal: DST_BRANCH_NAME does not exist inside DST_GIT_REPO"; exit; } } &&
    echo '[OK] All preconditions met'
}

# Import folder from one git repo to another git repo, including full history.
#
# Internally, it rewrites the history of the src repo (by creating
# a temporary orphaned branch; isolating all the files from REWRITE_FROM path
# to the root of the repo, commit by commit; and rewriting them again
# to the original path).
#
# Then it creates another temporary branch in the dest repo,
# fetches the commits from the rewritten src repo, and does a merge.
#
# Before any work is done, all the preconditions are verified: all folders
# and branches must exist (except REWRITE_TO folder in dest repo, which
# can exist, but does not have to).
#
# The code should work reasonably on repos with reasonable git history.
# I did not test pathological cases, like folder being created, deleted,
# created again etc. but probably it will work fine in that case too.
#
# In case you realize something went wrong, you should be able to reverse
# the changes by calling `undoImportFolderFromAnotherGitRepo` function.
# However, to be safe, please back up your repos just in case, before running
# the script. `git filter-branch` is a powerful but dangerous command.
importFolderFromAnotherGitRepo(){
    SED_COMMAND='s@\t\"*@\t'${REWRITE_TO}'@'

    verifyPreconditions &&
    cd "${SRC_GIT_REPO}" &&
      echo "Current working directory: ${SRC_GIT_REPO}" &&
      git checkout "${SRC_BRANCH_NAME}" &&
      echo 'Backing up current branch as FILTER_BRANCH_BACKUP' &&
      git branch -f FILTER_BRANCH_BACKUP &&
      SRC_BRANCH_NAME_EXPORTED="${SRC_BRANCH_NAME}-exported" &&
      echo "Creating temporary branch '${SRC_BRANCH_NAME_EXPORTED}'..." &&
      git checkout -b "${SRC_BRANCH_NAME_EXPORTED}" &&
      echo 'Rewriting history, step 1/2...' &&
      git filter-branch -f --prune-empty --subdirectory-filter ${REWRITE_FROM} &&
      echo 'Rewriting history, step 2/2...' &&
      git filter-branch -f --index-filter \
       "git ls-files -s | sed \"$SED_COMMAND\" |
        GIT_INDEX_FILE=\$GIT_INDEX_FILE.new git update-index --index-info &&
        mv \$GIT_INDEX_FILE.new \$GIT_INDEX_FILE" HEAD &&
    cd - &&
    cd "${DST_GIT_REPO}" &&
      echo "Current working directory: ${DST_GIT_REPO}" &&
      echo "Adding git remote pointing to SRC_GIT_REPO..." &&
      git remote add old-repo ${SRC_GIT_REPO} &&
      echo "Fetching from SRC_GIT_REPO..." &&
      git fetch old-repo "${SRC_BRANCH_NAME_EXPORTED}" &&
      echo "Checking out DST_BRANCH_NAME..." &&
      git checkout "${DST_BRANCH_NAME}" &&
      echo "Merging SRC_GIT_REPO/" &&
      git merge "old-repo/${SRC_BRANCH_NAME}-exported" --no-commit --allow-unrelated-histories &&
    cd -
}

# If something didn't work as you'd expect, you can undo, tune the params, and try again
undoImportFolderFromAnotherGitRepo(){
  cd "${SRC_GIT_REPO}" &&
    SRC_BRANCH_NAME_EXPORTED="${SRC_BRANCH_NAME}-exported" &&
    git checkout "${SRC_BRANCH_NAME}" &&
    git branch -D "${SRC_BRANCH_NAME_EXPORTED}" &&
  cd - &&
  cd "${DST_GIT_REPO}" &&
    git remote rm old-repo &&
    git merge --abort
  cd -
}

importFolderFromAnotherGitRepo
#undoImportFolderFromAnotherGitRepo
