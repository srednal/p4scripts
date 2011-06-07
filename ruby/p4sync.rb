#!/usr/bin/env ruby

# p4 sync wrapper
#
# If the filespec is [files]@label then the label is converted into a changelist
# that represents that label.  This avoids problems where the label's view
# might not include all the same files as are in your client spec.
# In such a case syncing to the label will cause your files outside the
# labelspec to be deleted (p4 sync #none).  Syncing to the matching changelist
# is safer in that the sync matches your clientspec rather than the label's spec.
#
# If the filespec is foo/...[@change|label], then each directory is synced separately.
# This reduces the load on the server for a large branch sync.
#
# This script also splits out the errors from the sync and display them separately.
# And resolve warnings (from p4 resolve -n) are also reported.
# The results of the sync (including change number, errors, and resolve warnings)
# are saved into the file ~/.p4sync (only the most recent invocation of this
# script is saved there, overwriting any previous results).

require 'perforce'

USAGE="\nUsage: #{$0} [-f] [-n] filespec"

# filespec is last arg, everything else is sync arg (-f or -n)
filespec = ARGV.pop

# gather remaining sync args: just -f and/or -n
syncargs = Array.new
ARGV.each do |a|
  raise USAGE unless a =~ /^-[fn]$/
  syncargs << a
end

p4 = P4.new

# Make sure there's a label
if ( filespec =~ /^\S*@\S+$/ )
  # split filespec, if any
  files, change = filespec.split( '@' )

  # look up change number for the label
  if ( change !~ /^(\d+)|(#(head|have))$/ ) then
    change = p4.changes('-m', '1', "@=#{change}").join.split(/\s+/)[1]
    raise "No changelist found for #{filespec}" if change.length == 0
  end
else
  # if no label, then just do sync to head
  files = filespec
  change = "#head"
end

changeno = "@#{change}" unless change =~ /^#(head|have)$/

#                puts "changeno=#{changeno}"
#                puts "files=#{files}"

# If doing a recursive sync (foo/...), then loop through
# the subdirectories and sync each individually
# This will reduce the load on the server
if ( files =~ /\.\.\.$/ ) then
  # replace ... with *
  filez = files.sub( /\.\.\.$/, '*')
  # files in that directory
  filelist = [ filez ]
  # and each subdir
  filelist.concat( p4.dirs_INFO( '-C', "#{filez}#{changeno}" ).collect{ |d| "#{d.chomp}/..." } )
else
  filelist = [ files ]
end

#                puts "filelist=#{filelist}"

syncErrs = Array.new

filelist.each do |f|
  # do the sync, show the result
  cmd = syncargs.clone << "#{f}#{changeno}"
  #              puts "cmd=#{cmd.inspect}"
  p4.sync_INFO( cmd ) { |out| puts out }
  # collect error messages from the cached command output
  #
  # Note that because we aer walking subdirectories individually, we will
  # see things such as //depot/foo/bar/...@123456 - file(s) up-to-date.
  # come out as an error, but that just means nothing got sync'ed
  # Dont collect those in syncErrs but display them as if they came from the sync above
  err = p4.sync_ERROR( cmd )
  if (err.length == 1 && err[0] =~ / - file\(s\) up-to-date\./ ) then
    puts err
  else
    syncErrs << err
  end
end

puts '=== Errors:', syncErrs unless syncErrs.empty?

# resolve warnings
resolveWarnings = p4.resolve('-n', files)
puts '=== Resolve:', resolveWarnings unless resolveWarnings.empty?

puts "=== Synced to #{change}"

# write info to file so later we can tell where we synced, etc
log = File.expand_path( '~/.p4sync' )

prev = ''
if File.exists?(log) then
  prev = File.readlines(log)
  prev.slice!(100,prev.length)
  prev.compact!
  prev.unshift("====\n")
end

File.open( log, 'w+' ) do |f|
  f.puts Time.now
  f.puts "p4labelsync #{syncargs} #{filespec}"
  f.puts "Synced to #{change}"
  f.puts 'Errors:', syncErrs unless syncErrs.empty?
  f.puts 'Resolve:', resolveWarnings unless resolveWarnings.empty?
  f.puts prev
end