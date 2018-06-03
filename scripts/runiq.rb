#!/usr/bin/ruby --disable-gems

##
## synopsis: does what uniq "pretends" to do, i.e.:
##    reads in lines, and only prints unique lines.
##    flags allow for ignoring case-sensitivity, using basename (for file paths!),
##    filesize (file paths) and hashing (file paths again, obviously).
##    unlike GNU uniq, runiq actually does what it says on the tin.
##


require "optparse"
require "digest"

def ispipe?
  return (not $stdin.tty?)
end

class RubyUniq
  def initialize(options)
    @options = options
    @uniq = {}
    $stdout.sync = true
    check_opts
  end

  def check_opts
    nocombine = %i(dofilesize dosha1)
    nocombine.each do |nm|
      if @options.has_key?(nm) then
        @options.each do |opt, val|
          if not nocombine.include?(opt) then
            raise ArgumentError, "cannot use #{nm} in combination with #{opt}!"
          end
        end
      end
    end
  end

  def seen?(line)
    data = line.dup.strip
    cm = data
    # some options MUST be processed before others.
    if @options.has_key?(:nocase) then
      cm = cm.downcase
      @options.delete(:nocase)
    end
    # other options change the types/values of @uniq altogether, and
    # cannot be combined with others, so they should (ideally) processed separately.
    # rest of options are processed here
    begin
      @options.each do |opt, val|
        case opt
          when :dobasename then
            cm = File.basename(cm)
          when :dodirname then
            cm = File.dirname(cm.strip)
          when :dofilesize then
            cm = File.size(data.strip)
          when :dosha1 then
            cm = Digest::SHA1.file(data.strip)
          when :dostripline then
            cm = data # again?
        end
      end
    rescue => e
      $stderr.puts("error: (#{e.class}) #{e.message}")
      return false
    end
    if not @uniq.key?(cm) then
      @uniq[cm] = {count: 0, line: data}
      return false
    else
      @uniq[cm][:count] += 1
    end
    return true
  end

  def printbefore(line, filename, *opts)
    hadprinted = false
    opts.each do |opt|
=begin
      case opt
        when :printcount then
          if @uniq.key?(line) then
            $stdout.printf("%8d:", @uniq[line] + 1)
            hadprinted = true
          end
        when :printfile then
          $stdout.printf("%s:", filename)
          hadprinted = true
      end
=end
    end
    $stdout.write(" ") if hadprinted
  end

  def writeln(line, filename)
    printbefore(line, filename, :printcount, :printfile)
    #$stdout.printf("%s\n", line)
    $stdout.puts(line)
  end

  def do_io(io, filename)
    cache = []
    mustcache = (@options.key?(:printcount) || @options.key?(:printfile))
    io.each_line do |line|
      if not seen?(line) then
        if mustcache then
          cache.push(line)
        else
          writeln(line, filename)
        end
      end
    end
    if not cache.empty? then
      if @uniq.size != cache.size then
        raise "this should not have happened!"
      else
        #@uniq.sort_by{|_, info| info[:count]}.each do |line, _|
        @uniq.sort_by{|_, info| info[:count]}.each do |cm, info|
          line = info[:line]
          writeln(line, filename)
        end
      end
    end
  end
end

begin
  options = {}
  prs = OptionParser.new{|prs|
    prs.on("-f", "--printfile", "print filename before each line"){|v|
      options[:printfile] = v
    }
    prs.on("-i", "--nocase", "make comparison case-insensitive"){|v|
      options[:nocase] = v
    }
    prs.on("-c", "--printcount", "print number of occurences"){|v|
      options[:printcount] = v
    }
    prs.on(nil, "--eval=<code>", "eval <code> as ruby code for every line prior to check (var is '$line')"){|v|
      raise NotImplementedError, "-e is not implemented yet"
    }
    prs.on(nil, "--basename", "apply File.basename() to every line prior checking"){|v|
      options[:dobasename] = v
    }
    prs.on(nil, "--dirname", "like -e, except using File.dirname"){|v|
      options[:dodirname] = v
    }
    prs.on(nil, "--size", "use filesizes instead of strings (cannot be combined)"){|v|
      options[:dofilesize] = v
    }
    prs.on(nil, "--hash", "use SHA1 hash for comparison (cannot be combined)"){|v|
      options[:dosha1] = v
    }
    prs.on(nil, "--strip", "strip each line prior to comparison"){|_|
      options[:dostripline] = true
    }
  }
  prs.parse!
  runiq = RubyUniq.new(options)
  if ispipe? then
    runiq.do_io($stdin, "<stdin>")
  else
    if ARGV.empty? then
      $stderr.puts("ERROR: no input files given, and no pipe present!")
      $stderr.puts(prs.help)
      exit(1)
    else
      ARGV.each do |filename|
        File.open(filename, "rb") do |fh|
          runiq.do_io(fh, filename)
        end
      end
    end
  end
end

