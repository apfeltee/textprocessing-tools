#!/usr/bin/ruby --disable-gems

require "optparse"
require "ostruct"

# maxargs ought to be retrieved with something like 'getconf ARG_MAX'
# on cygwin, this value is around 32k, so
# setting it to 1024*16 seems sensible-ish.
# note that this is going to fail **no matter what** for
# cmd.exe commands. i have no clue why.
SHELL_MAX_ARGS = (1024 * 25)  

class Nargs
  def initialize(iothing, opts, command)
    @io = iothing
    @opts = opts
    @command = command
    @linesep = $/
    @printonly = command.empty?
    if opts.nullbytes then
      @linesep = "\0"
    end
  end

  def verbose(fmt, *args)
    if @opts.verbose then
      str = (if args.empty? then fmt else sprintf(fmt, *args) end)
      $stderr.printf("nargs:verbose: %s\n", str)
    end
  end

  def real_spawn(com, *args)
    if @opts.testonly then
      return 0
    else
      return Process.spawn(com, *args)
    end
  end

  def real_wait(pid)
    if not @opts.testonly then
      Process.wait(pid)
    end
  end

  def real_kill(pid, status)
    if not @opts.testonly then
      Process.kill(pid, status)
    end
  end

  def build_command(values)
    # redefine commandline when a placeholder is defined,
    # even if $values doesn't contain any placeholders.
    # just to make sure we don't skip any.
    if @opts.placeholder != nil then
      newcom = []
      rx = Regexp.new(Regexp.quote(@opts.placeholder))
      @command.each do |s|
        if s.match(rx) then
          # when a placeholder is defined, then values will only
          # contain one value
          if values.length > 1 then
            # this seriously should never happen. i think.
            raise "fatal: ??? somehow values is longer than 1 (values=#{values.inspect}) ???"
          end
          newcom.push(s.gsub(rx, values.first))
        else
          newcom.push(s)
        end
      end
      #$stderr.printf("newcom=%p\n", newcom)
      return newcom
    end
    if @opts.reverseargs then
      values.reverse!
    end
    return [*@command, *values]
  end

  def doCommand(vals)
    com = build_command(vals)
    thisdir = Dir.pwd
    if @printonly then
      com.each do |v|
        $stdout.puts(v)
      end
    else

      verbose("built command: %p", com)
      pid = nil
      first = com.shift
      trap("INT") do
        $stderr.printf("caught ^C, killing %d\n", pid)
        real_kill(pid, 9)
      end
      # spawn our process
      pid = real_spawn(first, *com)
      verbose("spawn pid=%d", pid)
      # concurrency must be specified explicitly - otherwise, wait for process to finish
      if not @opts.concurrent then
        real_wait(pid)
        verbose("Process.wait(%d) has finished", pid)
      end

    end
  end

  def main
    cache = []
    # save current working directory in case '-d' was specified
    thisdir = Dir.pwd
    mustchdir = false
    begin
      @io.each_line(@linesep) do |line|
        val = line.strip
        # if -d is specified, try to get the directory of the value ...
        if @opts.samedir then
          valdir = File.dirname(val)
          # make sure it's actually cd'able ...
          if (valdir != nil) && (valdir != "") then
            # get basename and make sure its valid ...
            newval = File.basename(val)
            if (newval != nil) && (newval != "") then
              # if all is well(-ish?), then modify path and val accordingly
              verbose("-d: chdir %p", valdir)
              verbose("-d: val %p -> %p", val, newval)
              Dir.chdir(valdir)
              mustchdir = true
              val = newval
            end
          end
        end
        # run command as soon as specified maximum arguments have been reached
        if (cache.length >= @opts.maxargs) then #&& (@printonly == false) then
          doCommand(cache)
          cache = []
        end
        cache.push(val)
      end
      # leftovers might exist if maxargs wasn't reached
      if not cache.empty? then
        doCommand(cache)
      end
    ensure
      # return to original dir
      if mustchdir then
        verbose("returning back to original cwd %p", thisdir)
        Dir.chdir(thisdir)
      end
    end
  end
end

##
# this is pure filth, avert your eyes plz
##
begin
  $stdout.sync = true
  # some sensible defaults
  opts = OpenStruct.new(maxargs: SHELL_MAX_ARGS)
  # don't actually try to pre-process ARGV if there's already
  # a doubledash present
  if (not ARGV.grep(/^-/).empty?) && (ARGV.grep(/^--$/).empty?) then
    # if the first argument is not a switch, then stop
    # just stop processing switches altogether
    if (ARGV[0][0] != '-') then
      #$stderr.puts("bogus: first argument is not a switch")
      ARGV.unshift("--")
    else
      # otherwise, walk through ARGV, until the first argument (**after** ARGV[0]) that
      # is NOT a switch, but followed by a switch, is found. then "insert" a doubledash
      # before it, and continue as per usual! easy.
      newargv = []
      ARGV.each_with_index do |arg, i|
        if (i > 0) && ((arg[0] == '-') && (ARGV[i - 1][0] != '-')) then
          prev = newargv.pop
          #$stderr.puts("bogus: push(#{["--", prev, arg].inspect})")
          newargv.push("--", prev, arg)
        else
          newargv.push(arg)
        end
      end
      # now "replace" ARGV's content with newargv
      ARGV.replace(newargv)
    end
    #$stderr.puts("bogus: automatically added doubledash")
    #$stderr.puts("bogus: new ARGV: #{ARGV.inspect}")
  end
  # now the actual parsing can begin
  prs = OptionParser.new{|prs|
    prs.banner = (
      "process line-based input slightly better than xargs.\n" +
      "just like xargs, terminate nargs switch processing with '--', for example:\n" +
      "   ls *.txt | nargs -- file -bi\n" +
      "\n" +
      "supported options:\n"
    )
    prs.on("-0", "--null", "assume every line ends in \\0"){|v|
      opts.nullbytes = true
    }
    prs.on("-n<i>", "--maxargs=<i>", "pass maximum <i> args at once"){|v|
      opts.maxargs = v.to_i
      if opts.maxargs == 0 then
        $stderr.puts("error: --maxargs must be a number greater than zero!")
        exit(1)
      end
    }
    prs.on("-I<str>", "--replace=<str>", "use <str> as placeholder in the command. implies '-s'"){|v|
      opts.placeholder = v
      opts.maxargs = 1
    }
    prs.on("-d", "--samedir", "execute command in same directory/directories as their arguments - implies '-1'!"){|_|
      opts.samedir = true
      opts.maxargs = 1
    }
    prs.on("-r", "--reverse", "reverse argument list prior to passing it to the command"){|v|
      opts.reverseargs = true
    }
    prs.on("-1", "--singlearg", "equivalent to '--maxargs=1'"){|v|
      opts.maxargs = 1
    }
    prs.on("-c", "--concurrent", "start processes concurrently (implies `-1`)"){|v|
      opts.maxargs = 1
      opts.concurrent = true
    }
    prs.on("-t", "--test", "test only, do not actually run any commands (useful with '-v')"){|_|
      opts.testonly = true
    }
    prs.on(nil, "--verbose", "enable verbose messages"){|v|
      opts.verbose = true
    }
  }
  prs.parse!
  Nargs.new($stdin, opts, ARGV).main
end
