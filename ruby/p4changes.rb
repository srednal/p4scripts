#!/usr/bin/env ruby
# Report of open changelists

require 'perforce'

BLANK = /^\s*$/
TAB = /^\t/
INDENT = '    '

p4 = P4.new

# Note that p4 sorts these backwards (newer ones first).
# So we will just have to sort them ourselves
changes = Array.new
p4.changes( '-l', '-s', 'pending', '-c', p4.p4client ) do |l|
  next if l =~ BLANK    # strip blank lines
  if l !~ TAB
    changes << l       # a change info line, add it to the changes array
  else
    changes.last << l.gsub( TAB, INDENT )  # a change description, append it to its change element
  end
end

# now we can sort the array and print it (it still contains newlines)
puts changes.sort
