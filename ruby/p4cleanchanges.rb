#!/usr/bin/env ruby
# Delete empty pending changelists

require 'perforce'

USAGE="\nUsage: #{$0}\n"
raise USAGE if ARGV.length != 0
 
p4 = P4.new

# display pending changes
p4.pending_change_numbers.each do |c|
  # describe's info is files
  puts p4.change( '-d', c ) if p4.describe_INFO(c).empty?
end
