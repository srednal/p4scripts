This is a collection of (mostly Ruby) scripts I used to simplify and automate some tasks with Perforce SCM.
It contains the following:

p4pending - list of open files organized by changelist
p4changes - list open changelists and descriptions
p4cleanchanges - delete any empty pending changelists
p4default2change - move all open files to a given changelist
p4revertchange - revert all files in a given changelist (and delete the changelist)
p4sync - wrapper around p4 sync. Syncs immediate child directories separately (can reduce server load for large syncs).
      Also collects errors (i.e. can't clobber, etc) and prints them at the end where you can see them.
p4not - Find files that are out of sync with p4 (not in depot or in changelist, etc).
p4openzip - (shell script) Create a zip file of all open changes (or a set of zip files per open changelist).
      Also can unzip, recreating a change from a p4openzip archive.

Each of the above ruby scripts has a shell script wrapper to run the ruby.  This was my prefered way to graft these into
my PATH (the shell scripts sit in ~/bin).

There is also a perforce.rb containing a P4 class, which the above ruby scripts use to interact with Perforce.


