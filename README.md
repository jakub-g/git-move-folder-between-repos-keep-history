# git-import-repo

Import repo into a subfolder of another one and keep the graph of snapshots. 

*Note: git sha1-s are not preserved after migration (it's not possible in general case; before merging code from one repo to another, the script recreates git commits, filtering out the changes done outside of the folder being moved)*

# Usage

Clone the repo and run the help:

```bash
❯ ./import-repo.sh -h
usage: import-repo.sh [-h] -s LOCAL_SRC_GIT_REPO -d LOCAL_DST_GIT_REPO -sbr SOURCE_BRANCH -dbr DESTINATION_BRANCH -nstp NEW_SUBTREE_PATH [--do-not-migrate-lfs]

Import a repository into a subfolder of another git repository, preserving full history source repository.

optional arguments:
  -h, --help            show this help message and exit
  -s LOCAL_SRC_GIT_REPO, --local-src-git-repo LOCAL_SRC_GIT_REPO
                        Path to the root of the local git repo to import
  -d LOCAL_DST_GIT_REPO, --local-dst-git-repo LOCAL_DST_GIT_REPO
                        Path to the root of the local destination git repo
  -sbr SOURCE_BRANCH, --source-branch SOURCE_BRANCH
                        Branch source name to import from
  -dbr DESTINATION_BRANCH, --destination-branch DESTINATION_BRANCH
                        Branch destination name to import to
  -nstp NEW_SUBTREE_PATH, --new-subtree-path NEW_SUBTREE_PATH
                        Subtree path relative to the root of the destination repo
  --do-not-migrate-lfs  if lfs files are detected, those will be exported in source repo and re-imported in target repo. The operation might take a long time. Use this flag to avoid
                        this process and deal with LFS manually later. Be sure to know what you are doing if you use this flag!
```

The script uses the git filter-repo module. Check how to install it at: https://github.com/newren/git-filter-repo/blob/main/INSTALL.md

DO NOT RUN THIS SCRIPT ON YOUR ORIGINAL REPOS. Make full copies of the repos you want to play with before running the script - better safe than sorry. The script uses some dangerous git methods that rewrite repo history.

You've been warned :) Now back up your stuff and enjoy the script.

If you like it, [please upvote the StackOverflow answer of the original author!!](https://stackoverflow.com/a/47081782/245966).

## Support for LFS!!

It also provides support for copying over all the LFS file of the source repo keeping all the history. In order to help the portability of this git feature however, it is necessary to export all the LFS file first.
This might take a considerable amount of time. Also after the migration the user is responsible for completing the merge first and them actually re-import the files as LFS.
NOTE: git will already track the LFS files in the `.gitattribute` that is imported as well with all the history at `$LOCAL_DST_GIT_REPO/$NEW_SUBTREE_PATH/.gitattribute`. It responsibility of the user to decide if unify such file with the `$LOCAL_DST_GIT_REPO/.gitattribute` or keeping it separate. There are pro and cons in both approaches so the script by default doesn't try to over-do about it.
Given that the exporting step in the source repo might take a long time, there is the possibility to let the script doing nothing about it by passing `--do-not-migrate-lfs`. Obviously this might create an inconsistent state so be sure to know what you are doing.

