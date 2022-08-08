# git-impoort-repo

Import repo into a subfolder of another one and keep the graph of snapshots

*Note: git sha1-s are not preserved after migration (it's not possible in general case; before merging code from one repo to another, the script recreates git commits, filtering out the changes done outside of the folder being moved)*

# Usage

Clone the repo and run the help:

```
❯ ./import-repo.sh -h
usage: import-repo.sh [-h] -s LOCAL_SRC_GIT_REPO -d LOCAL_DST_GIT_REPO -sbr SOURCE_BRANCH -dbr DESTINATION_BRANCH -nstp NEW_SUBTREE_PATH

Copy a folder from one git repo to another git repo, preserving full history of the folder.

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
```

The script uses the git filter-repo module. Check how to install it at: https://github.com/newren/git-filter-repo/blob/main/INSTALL.md

DO NOT RUN THIS SCRIPT ON YOUR ORIGINAL REPOS. Make full copies of the repos you want to play with before running the script - better safe than sorry. The script uses some dangerous git methods that rewrite repo history.

You've been warned :) Now back up your stuff and enjoy the script.

If you liked it, [please upvote the StackOverflow answer of the original author at](https://stackoverflow.com/a/47081782/245966).
