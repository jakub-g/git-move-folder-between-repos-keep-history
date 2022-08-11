#!/bin/bash

# Starting point: https://github.com/jakub-g/git-move-folder-between-repos-keep-history 
# forked in https://github.com/tetractius/git-import-repo-into-another-in-subfolder-and-keep-history
# Using argparse python-like from https://github.com/nhoffman/argparse-bash

ARGPARSE_DESCRIPTION="Import a repository into a subfolder of another git repository, preserving full history source repository."
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
parser.add_argument('--do-not-migrate-lfs', action='store_true', default=False,
                    help='if lfs files are detected, those will be exported in source repo and re-imported in target repo. The operation might take a long time. '
                         'Use this flag to avoid this process and deal with LFS manually later. Be sure to know what you are doing if you use this flag!')
EOF

# NEW_SUBTREE_PATH must have a trailing slash.
if [[ "${NEW_SUBTREE_PATH}" != */ ]]; 
then
  NEW_SUBTREE_PATH=${NEW_SUBTREE_PATH}/
  echo "Adding trailing slash NEW_SUBTREE_PATH=${NEW_SUBTREE_PATH}"
fi

verifyPreconditions() {

    echo "-- Checking if git-filter-repo is installed"
    [[ $(type -P "git-filter-repo") ]] && echo "git-filter-repo is available"  || 
	        { echo "git-filter-repo is NOT available in PATH. Please refer to https://bit.ly/3bEmCVG
			for installation instructions" 1>&2; exit 1; }
    echo "-- Checking if '${LOCAL_SRC_GIT_REPO}' is a git repo..." &&
      { test -d "${LOCAL_SRC_GIT_REPO}/.git" || { echo "Fatal: '${LOCAL_SRC_GIT_REPO}' is not a git repo"; exit; } } &&
    echo "-- Checking if '${LOCAL_SRC_GIT_REPO}' has LFS files..." &&
       { cd "${LOCAL_SRC_GIT_REPO}"; 
       if [[ $(git lfs ls-files) ]]; 
       then 
        echo "There are the following LFS files: this tool will try export those and re-import them in the target repo."
        echo "Use '--do-not-migrate-lfs' to avoid this behaviour."
        git lfs ls-files --size; 
        export THERE_ARE_LFS=1 
       else
        echo "No LFS files to found in '${LOCAL_SRC_GIT_REPO}' repo"
        export THERE_ARE_LFS=0
        fi 
      } &&
    echo "-- Checking if '${LOCAL_DST_GIT_REPO}' is a git repo..." &&
      { test -d "${LOCAL_DST_GIT_REPO}/.git" || { echo "Fatal: '${LOCAL_DST_GIT_REPO}' is not a git repo"; exit; } } &&
    echo "-- Checking if '`pwd`/${NEW_SUBTREE_PATH}' is not empty..." &&
      { test -n "${NEW_SUBTREE_PATH}" || { echo "Fatal: '${NEW_SUBTREE_PATH}' subtree path is not empty"; exit; } } &&
    echo "-- Checking if '${LOCAL_SRC_GIT_REPO}' repo has a branch with name '${SOURCE_BRANCH}'" &&
      { cd "${LOCAL_SRC_GIT_REPO}"; git checkout "${SOURCE_BRANCH}" ; git rev-parse --verify "${SOURCE_BRANCH}" || { echo "Fatal: '${SOURCE_BRANCH}' branch does not exist inside '${LOCAL_SRC_GIT_REPO}' repo"; exit; } } &&
    echo "-- Checking if '${LOCAL_DST_GIT_REPO}' repo has a branch with name '${DESTINATION_BRANCH}'" &&
      { pushd "${LOCAL_DST_GIT_REPO}"; git rev-parse --verify "${DESTINATION_BRANCH}" || { echo "ATTENTION!!: '${DESTINATION_BRANCH}' branch does not exist inside '${LOCAL_DST_GIT_REPO}'. Creating it now.";  git branch "${DESTINATION_BRANCH}"; } } &&
    echo "-- [OK] All preconditions met !!"
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

    verifyPreconditions 

    # If I have LFS file it is better to have git to skip LFS operations at all time
    if [[ "$THERE_ARE_LFS" == 1 ]]; 
    then
      echo "-- Disabling git smudge operation because of LFS" &&
      GIT_LFS_SKIP_SMUDGE=1 
    fi
    
    pushd "${LOCAL_SRC_GIT_REPO}" &&
      echo "-- Current working directory: ${LOCAL_SRC_GIT_REPO}" &&
      git checkout "${SOURCE_BRANCH}" &&
      echo "-- Backing up current branch as '${FILTER_BRANCH_BACKUP}'" &&
      git branch -f FILTER_BRANCH_BACKUP &&
      SOURCE_BRANCH_EXPORTED="${SOURCE_BRANCH}-exported" &&
      echo "-- Creating temporary branch '${SOURCE_BRANCH_EXPORTED}'..." &&
      git checkout -b "${SOURCE_BRANCH_EXPORTED}" &&
      if [[ "$THERE_ARE_LFS" == 1 ]]; 
      then
        echo "-- Saving the list of LFS files"
        lfs_tmpfile=$(mktemp /tmp/import-repo-lfs-list.XXXXXX)
        git lfs ls-files |  awk '{ s = ""; for (i = 3; i <= NF; i++) s = s $i " "; print s }' > $lfs_tmpfile
        echo "-- Exporting back all the file from LFS. This might take awhile"
        git lfs migrate export --everything --include="*"
      fi
      echo "-- Rewriting history..." &&
      git filter-repo -f --prune-empty auto --path-rename :${NEW_SUBTREE_PATH} &&
      echo "-- ...done"
    popd &&
    
    pushd "${LOCAL_DST_GIT_REPO}" &&
      echo "-- Current working directory: ${LOCAL_DST_GIT_REPO}" &&
      echo "-- Adding git remote pointing to '${LOCAL_SRC_GIT_REPO}'..." &&
      git remote add old-repo ${LOCAL_SRC_GIT_REPO} &&
      echo "-- Fetching from ${LOCAL_SRC_GIT_REPO}..." &&
      git fetch old-repo "${SOURCE_BRANCH_EXPORTED}" &&
      echo "-- Checking out ${DESTINATION_BRANCH} branch..." &&
      git checkout "${DESTINATION_BRANCH}" &&
      echo "-- Merging the following:" &&
      echo "-- Source repo - branch: ${LOCAL_SRC_GIT_REPO} - ${SOURCE_BRANCH}" &&
      echo "-- Target repo - branch: ${LOCAL_DST_GIT_REPO} - ${DESTINATION_BRANCH}" &&
      git merge "old-repo/${SOURCE_BRANCH}-exported" --allow-unrelated-histories --no-commit 
      echo ""
      echo "-- DONE!! Now check the ${LOCAL_DST_GIT_REPO} repo, adjust the final things and complete the process by doing 'git merge --continue'"
      if [[ "$THERE_ARE_LFS" == 1 && "$DO_NOT_MIGRATE_LFS" != "yes" ]]; 
      then
        echo "" 
        echo "-------------------------------------------------------------------------------------------------------------" 
        echo "-- ATTENTION!! The source branch had LFS. After you completed the merge with 'git merge --continue' you will"
        echo "-- have to do the following step for ensuring that LFS are re-imported correctly."
        echo "-- (The LFS tracking for these files is still `realpath ${LOCAL_DST_GIT_REPO}/${NEW_SUBTREE_PATH}/.gitattribute.` "
        echo "-- You will have to decide if unifying those to the target repo `realpath ${LOCAL_DST_GIT_REPO}/.gitattribute`  "
        echo "-- or leaving those where they are, at a later stage according to you need)"
        echo "-- "
        echo "-- Now I will generate a list of commands that you have to do to re-import LFS with the same history:"
        echo ""
        cat $lfs_tmpfile | while read lfs_file_to_reimport;
        do
          # NOTE: without slashes because we added previously
          # NOTE: the --no-rewrite is important because it just add a new migrated path
          #       rather than trying to change a old outdated one
          echo "git lfs migrate import --no-rewrite \"${NEW_SUBTREE_PATH}$lfs_file_to_reimport\""
        done
        echo "git lfs pull"
        echo "git lfs ls-files --all"
        echo ""
        echo "-- After you can check the status with 'git lfs status' and/or 'git lfs ls-files --all' and/or 'git lfs track' and if you are happy you can commit those changes"
      fi
      echo "-- May the odds be always in your favor!"
    popd 
}

importFolderFromAnotherGitRepo
