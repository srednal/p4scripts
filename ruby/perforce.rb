require 'pathname'
require 'open3'

class P4

  def config( what )
    unless @config

      @config = Hash.new

      # This is all pretty unixy...
      # get p4config filename
      if ENV.has_key?('P4CONFIG')

        p4config = Pathname.new( ENV['P4CONFIG'] )

        # if relative, find the real one looking up the dir tree
        if p4config.relative?
          dir = Pathname.pwd
          while dir != '/' && ! ( dir + p4config ).exist? do
            dir = dir.dirname
          end
          p4config = dir + p4config
        end

        # read p4config file into config hash if it exists
        open( p4config ) do |f|
          f.each do |line|
            /^\s*(P4\S*)\s*=\s*(.*)$/.match(line)
            @config[$1] = $2
          end
        end unless p4config.nil? || ! p4config.exist?

      end

      # grab env overrides
      ENV.each { |k,v| @config[k] = v if k =~ /^P4/ }
    end

    @config[what]
  end

  def p4client
    config('P4CLIENT')
  end

  # filters
  @@filter = {
    :INFO => /^info1?: /,
    :TEXT => /^text: /,
    :ERROR => /^error: /,
    :WARNING => /^warning: /,
    :EXIT => /^exit: /,
    :RAW => /^/
  }
  @@body_filter = /#{@@filter[:INFO]}|#{@@filter[:TEXT]}|#{@@filter[:ERROR]}|#{@@filter[:WARNING]}/

  # run p4 command
  #    foo(args...) -> stdout_array
  #       runs p4 foo args...
  #       will raise exception if stdout is empty and stderr is not
  #    foo(args...) {|o,e| block} -> result of block
  #       runs p4 foo args...
  #       where o and e are arrays of stdout and stderr
  #    foo_XXX(args...)  runs p4 -s foo args with a filter, returning only
  #       the matched result from p4 -s.  Valid filters (for XXX) are:
  #          INFO (matches info: or info1:)
  #          TEXT (matches text:)
  #          ERROR (matches error:)
  #          WARNING (matches warning:)
  #          EXIT (matches exit:)
  #          RAW (matches everything - results include the -s prefixes
  #       Except for RAW, all output will have the -s prefix removed.
  #       Default (without filter) will always run p4 with -s and returns any result matching
  #       info:, info1:, text:, error:, or warning:.
  def method_missing( p4command, *args )
    @cache = Hash.new unless @cache

    # allow a command of the form command_FILTER
	  md = /^([^_]+)_([A-Z]+)$/.match p4command.id2name
  	if ! md.nil?
      p4command = md[1]
	    filter = @@filter[ md[2].to_sym ]
    else
	    filter = @@body_filter
	  end

    # quote each arg, to handle the case where filenames contain spaces
    # quote with single-quotes so the shell (*nix) doesn't expand
    # any characters (ugh)
    quoted_args=args.flatten.collect {|a| "\'#{a}\'" }.join(' ')
    cmd = "p4 -s #{p4command} #{quoted_args}"
    result = Array.new
    if @cache.has_key? cmd
      @cache[cmd].each  do |line|
         if line =~ filter
          if defined? yield
            yield $'
          else
            result << $'
          end
        end
      end
    else
      @cache[cmd] = ''
      IO.popen( cmd ) do |out|
        out.each do |line|
          @cache[cmd] << line
          if line =~ filter
            if defined? yield
              yield $'
            else
              result << $'
            end
          end
        end
      end
    end
    result
  end


  # ensure p4 is there
  def ping?
    info_EXIT { |code| return code != 0 }
    false
  end

  # raise an error if p4 not responding, error contains stderr from p4 info
  def ping
    raise info_ERROR.join unless ping?
  end

  # same as info
  def to_s
    info
  end

  # return depot files and change info for files in default changelist as array
  def default_filespecs
    # grab default change and truncate everything up to Files: line
    trunc = 0
    clist = change '-o'
    clist.each_with_index { |l,i| trunc = i if l =~ /^Files:$/ }
    return Array.new if trunc == 0
    clist[ 0..trunc ] = nil
    # remove blanks
    clist.collect { |l| l.strip }.reject { |l| l =~ /^$/ }
  end

  # return depot filenames for files in default changelist as array
  def default_files
    default_filespecs.collect { |l| l.split('#')[0].strip }
  end

  # pending change numbers, as an array
  def pending_change_numbers
    changes( '-s', 'pending', '-c', p4client ).collect {|x| x.split[1] }.sort
  end

end

if __FILE__ == $0
  p4 = P4.new
  puts p4.info_RAW
  puts "P4 is #{p4.ping? ? 'UP' : 'DOWN'}"
  p4.ping
end