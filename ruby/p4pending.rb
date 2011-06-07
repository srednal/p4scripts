#!/usr/bin/env ruby
# Report of opened files by changelist

require 'perforce'

BLANK = /^\s*$/
AFFECTED = /^Affected files \.\.\./
IGNORE = /#{BLANK}|#{AFFECTED}/
TAB = /^\t/
INDENT = '    '

p4 = P4.new

# display pending changes
p4.pending_change_numbers.each do |changeno|
  # text is description
  p4.describe_TEXT(changeno) do |t|
    puts t.gsub(TAB, INDENT) unless t =~ IGNORE
  end
  # info will contain files
  # note this second call to describe is cached, only the INFO filtering is actually done
  p4.describe_INFO(changeno) do |f|
    puts INDENT + f
  end
end

# default changelist
puts 'Default Change:'
p4.default_filespecs.each { |f| puts INDENT + f }
