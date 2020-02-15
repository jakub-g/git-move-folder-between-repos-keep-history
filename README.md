# git-move-folder
Move folder from one git repo to another, with full history.

# Usage

Check the `.sh` file. You don't need advanced bash skills. Basically you should:

1. Copy this file to a handy place (outside of the repos you modify)
2. Modify the variables the top of the file
3. Make sure the repos modified are in clean state (`git status`)
4. Run the `.sh` file and let it do the magic

Note that the script will go over each commit in git history one by one, so it may take a while to complete on huge repos (progress is logged though on each commit).

It is however optimized to skip the commits that do not touch the folder moved, so if the folder is just a small part of a huge repo, it should be relatively fast.

If something goes wrong, you can comment out (with `#`, or just delete the line) the `importFolder...` method call at the end of the file,  uncomment the `undoImport...` method call, run the script to undo, then modify the params or the code itself, and rerun.

Even if I put a lot of safety belts (`verifyPreconditions`) and an undo functionality , for extra safety, DO NOT RUN THIS SCRIPT ON YOUR ORIGINAL REPOS. Make full copies of the repos you want to play with before running the script - better safe than sorry. The script uses some dangerous git methods that rewrite repo history.

You've been warned :) Now back up your stuff and enjoy the script.

If you liked it, [please upvote my StackOverflow answer](https://stackoverflow.com/a/47081782/245966).
