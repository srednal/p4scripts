#!/usr/bin/env ruby
# Revert files in a changelist and delete the change

require 'perforce'

USAGE="\nUsage: #{$0} changeno...\n"

raise USAGE unless ARGV.length != 0

p4 = P4.new

ARGV.each do |c|
  raise USAGE unless c =~ /^\d+$/
  puts p4.revert( '-c', c, '//...' )
  puts p4.change( '-d', c )
end
