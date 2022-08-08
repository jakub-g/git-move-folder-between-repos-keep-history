#!/bin/bash

# Starting point: https://github.com/jakub-g/git-move-folder-between-repos-keep-history 
# forked in https://github.com/tetractius/git-move-folder-between-repos-keep-history
# Using argparse python-like from https://github.com/nhoffman/argparse-bash

ARGPARSE_DESCRIPTION="Copy a folder from one git repo to another git repo, preserving full history of the folder."
source $(dirname $0)/argparse.bash || exit 1
argparse "$@" <<EOF || exit 1 
parser.add_argument('-s', '--local-src-git-repo', type=str,
                    help='Path to the root of the local git repo to import', 
                    required=True)
parser.add_argument('-d', '--local-dst-git-repo', type=str,
                    help='Path to the root of the local destination git repo', 
                    required=True)
parser.add_argument('-sbr', '--source-branch', type=str,
                    help='Branch source name to import from', 
                    required=True)
parser.add_argument('-dbr', '--destination-branch', type=str,
                    help='Branch destination name to import to', 
                    required=True)
parser.add_argument('-nstp', '--new-subtree-path', type=str,
                    help='Subtree path relative to the root of the destination repo', 
                    required=True)
EOF


# NEW_SUBTREE_PATH must have a trailing slash.
if [[ "${NEW_SUBTREE_PATH}" != */ ]]; 
then
  NEW_SUBTREE_PATH=${NEW_SUBTREE_PATH}/
  echo "Adding trailing slash NEW_SUBTREE_PATH=${NEW_SUBTREE_PATH}"
fi

verifyPreconditions() {

    [[ $(type -P "git-filter-repo") ]] && echo "git-filter-repo is available"  || 
	        { echo "git-filter-repo is NOT available in PATH. Please refer to https://bit.ly/3bEmCVG
			for installation instructions" 1>&2; exit 1; }
    #echo 'Checking if LOCAL_SRC_GIT_REPO is a git repo...' &&
      { test -d "${LOCAL_SRC_GIT_REPO}/.git" || { echo "Fatal: LOCAL_SRC_GIT_REPO is not a git repo"; exit; } } &&
    #echo 'Checking if LOCAL_DST_GIT_REPO is a git repo...' &&
      { test -d "${LOCAL_DST_GIT_REPO}/.git" || { echo "Fatal: LOCAL_DST_GIT_REPO is not a git repo"; exit; } } &&
    #echo 'Checking if NEW_SUBTREE_PATH is not empty...' &&
      { test -n "${NEW_SUBTREE_PATH}" || { echo "Fatal: NEW_SUBTREE_PATH is empty"; exit; } } &&
    #echo 'Checking if LOCAL_SRC_GIT_REPO has a branch SOURCE_BRANCH' &&
      { cd "${LOCAL_SRC_GIT_REPO}"; git rev-parse --verify "${SOURCE_BRANCH}" || { echo "Fatal: SOURCE_BRANCH does not exist inside LOCAL_SRC_GIT_REPO"; exit; } } &&
    #echo 'Checking if LOCAL_DST_GIT_REPO has a branch DESTINATION_BRANCH' &&
      { cd "${LOCAL_DST_GIT_REPO}"; git rev-parse --verify "${DESTINATION_BRANCH}" || { echo "Fatal: DESTINATION_BRANCH does not exist inside LOCAL_DST_GIT_REPO"; exit; } } &&
    echo '[OK] All preconditions met'
}

# Import full git repo to another git repo in a subdirectory, including full history.
#
# Internally, it rewrites the history of the src repo by adding a prefix path
# of desired subfolder.
#
# Then it creates another temporary branch in the dest repo,
# fetches the commits from the rewritten src repo, and does a merge.
#
# Before any work is done, all the preconditions are verified: all folders
# and branches must exist (except NEW_SUBTREE folder in dest repo, which
# can exist, but does not have to).
#
# The code should work reasonably on repos with reasonable git history.
# I did not test pathological cases, like folder being created, deleted,
# created again etc. but probably it will work fine in that case too.
#
# In case you realize something went wrong, destroy all you local repo,
# fix this script and start again

importFolderFromAnotherGitRepo() {

    verifyPreconditions &&
    pushd "${LOCAL_SRC_GIT_REPO}" &&
      echo "Current working directory: ${LOCAL_SRC_GIT_REPO}" &&
      git checkout "${SOURCE_BRANCH}" &&
      echo 'Backing up current branch as FILTER_BRANCH_BACKUP' &&
      git branch -f FILTER_BRANCH_BACKUP &&
      SOURCE_BRANCH_EXPORTED="${SOURCE_BRANCH}-exported" &&
      echo "Creating temporary branch '${SOURCE_BRANCH_EXPORTED}'..." &&
      git checkout -b "${SOURCE_BRANCH_EXPORTED}" &&
      
      echo 'Rewriting history...' &&
      git filter-repo -f --prune-empty auto --path-rename :${NEW_SUBTREE_PATH} &&
      echo '...done'
    popd &&
    
    pushd "${LOCAL_DST_GIT_REPO}" &&
      echo "Current working directory: ${LOCAL_DST_GIT_REPO}" &&
      echo "Adding git remote pointing to LOCAL_SRC_GIT_REPO..." &&
      git remote add old-repo ${LOCAL_SRC_GIT_REPO} &&
      echo "Fetching from LOCAL_SRC_GIT_REPO..." &&
      git fetch old-repo "${SOURCE_BRANCH_EXPORTED}" &&
      echo "Checking out DESTINATION_BRANCH..." &&
      git checkout "${DESTINATION_BRANCH}" &&
      echo "Merging LOCAL_SRC_GIT_REPO/" &&
      git merge "old-repo/${SOURCE_BRANCH}-exported" --allow-unrelated-histories --no-commit &&
    popd 
}

importFolderFromAnotherGitRepo
