#!/usr/bin/env ruby
# Move everything in default changelist to specified changelist

require 'perforce'

change = ARGV[0] || fail( "\nUsage: #{$0} changenumber\n" )

p4 = P4.new
puts  p4.reopen( '-c', change, p4.default_files )
