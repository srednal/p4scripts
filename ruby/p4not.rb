#!/usr/bin/env ruby

# == Synopsis
#
# p4not: Calculate what files, recursively from current directory, are on disk but not known to P4.
#
# == Usage
#
# p4not [OPTION]
#
# --help,   -h:  show help
# --quiet,  -q:  don't print anything about out-of-sync files
# --delete, -d:  delete files not known to p4
# --sync,   -s:  force-sync files that are different in p4
#

require 'perforce'
require 'find'
require 'pathname'
require 'getoptlong'
require 'rdoc/usage'

class P4Not
  attr_reader :client_files
  attr_reader :diff_files
  attr_reader :unmanaged_files
  
  def initialize()

    # Use p4 internal diff
    ENV.delete 'P4DIFF'

    @p4 = P4.new
    @p4.ping   # before we waste any time, make sure p4 is up

    @client_files = Array.new

    Pathname.new('.').find{|path| @client_files << path if path.file? }

    # sort client files, otherwise the natural ordering is not always what we want
    @client_files.sort!

    @diff_files = Array.new
    @unmanaged_files = Array.new
  end
  
  def run( range=nil )
    
    cf = range.nil? ? @client_files : @client_files[range]
  
    # Which of these are not known to p4
    # 'have' files will go to stdout (ignore)
    # If anything showed up in not have other than "not on client",
    #   there is something wrong - show them as "unknown state" warnings
    not_in_p4 = Array.new
    @p4.have_ERROR(cf) do |have_file|
      md = / - file\(s\) not on client\.$/.match have_file
      if md.nil?
        # Error but not expected message, these files have unknown status, just spew them out
        puts have_file
      else
        # despite the somewhat misleading error message, these files are not known to p4 
        not_in_p4 << md.pre_match
      end
    end unless cf.empty?

    # Find the not_in_p4 files that are not opened (i.e. for add)
    # These are the real rogues
    @p4.opened_ERROR( not_in_p4 ) do |n|
      f = n.sub( / - file\(s\) not opened on this client\.$/, '' )
      @unmanaged_files << f.chomp
    end unless not_in_p4.empty?

    # Report hanged files that aren't open but diff from depot
    @p4.diff_INFO( '-se', cf ) do |f|
      @diff_files << f.chomp
    end unless cf.empty?
  end
  
  
  def report
  
    @unmanaged_files.each { |f| puts f }
    @diff_files.each{ |f| puts "DIFF: #{f}" }
    puts "INFO: Total files on client: #{@client_files.size}"
    puts "INFO: Files on client, but not in p4: #{@unmanaged_files.size}"
    puts "INFO: Files different in p4: #{@diff_files.size}"
  
  end

  def delete_unmanaged
    return if @unmanaged_files.empty?
    puts "INFO: Deleting #{@unmanaged_files.size} unmanaged files"
    FileUtils.rm( @unmanaged_files )
  end
  
  def sync_diffs
    return if @diff_files.empty?
    puts "INFO: Force-syncing #{@diff_files.size} different files."
    @p4.sync( '-f', @diff_files) { |f| puts f }
  end

end

if __FILE__ == $0
  
  p4not = P4Not.new()
    
  opts = GetoptLong.new(
      [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
      [ '--quiet', '-q', GetoptLong::NO_ARGUMENT ],
      [ '--delete', '-d', GetoptLong::NO_ARGUMENT ],
      [ '--sync', '-s', GetoptLong::NO_ARGUMENT ]
  )

  quiet = false
  delete = false
  sync = false
  
  opts.each do |opt, arg|
    case opt
      when '--help'
        RDoc::usage
      when '--quiet'
        quiet = true
      when '--delete'
        delete = true
      when '--sync'
        sync = true
    end
  end

  puts "Checking p4 for #{p4not.client_files.size} local files on client" unless quiet
  
  # run in batches of 1000 files (otherwise p4 comand may overflow)
  batch_size = 1000
  (0..p4not.client_files.size).step(batch_size) do |i|
    p4not.run(i .. i+batch_size-1)
  end
  
  p4not.report unless quiet
  p4not.delete_unmanaged if delete
  p4not.sync_diffs if sync
  
end