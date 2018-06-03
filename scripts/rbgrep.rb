#!/usr/bin/ruby --disable-gems
=begin

rbgrep is like grep, except with a few modifications I deem rather important:
supporting groups. and not just by index, but named groups as well!
GNU grep does not seem to support it ouf the box, so I wrote my own.
if you don't know what I mean, then please read: https://www.regular-expressions.info/refcapture.html


by default, rbgrep will behave (almost) identical to posix grep, save for a few limitations:
  - rbgrep doesn't (can't) highlight what is actually matched, due to Regexp lacking context functionality
  - no context printing because of see above (no -b, -o, -B, -A, or -C) [*]
  - will be slower by definition (sorry ruby fans, no point in beating around the bush)
  - rbgrep will print binary output, whether you like it or not. grep does some special stream data checking,
    and implementing that goes far beyond for what rbgrep is meant for
  - short options can be combined, but not necessarily to the same extend as GNU getopt.
    rbgrep uses optparse, which, while very powerful, isn't quite as advanced as GNU getopt

  [*] context awareness might be bolted on using IO#lineno, but it's never going to be
      anywhere as good as grep does it. libpcre has explicit range context, but Regexp
      (which uses onigurama iirc) does not, i think. either way, it's not that important
      to me right now, but if you want to add it, go right ahead!

example usage:

  # search for <meta> redirects, ignoring case, and print the first matched capture (-a1) within
  $ rbgrep -i '<meta\s*.*url=(http.*)"' -a1 somefiles*.html

  # same as above, but recursively without explicitly adding files, and
  # without printing filenames
  $ rbgrep -irfa1 '<meta\s*.*url=(http.*)"'
  

=end

require "optparse"
require "ostruct"
require "find"

### note! ###
# using :chunkwise causes IO#lineno to fail (i.e., return 0).
# probably because ruby only tracks linefeeds in IO#each_line.
DEFAULT_READMODE = :linewise



class IOChunkReader
  def initialize(fh, readmode, rmdata)
    @handle = fh
    @readmode = readmode
    @rmdata = rmdata
    @ref = nil
    @reftype = :nil
    initref
  end

  def initref
    case @readmode
      when :linewise then
        @reftype = :iterator
        @ref = @handle.each_line
      when :chunkwise then
        @reftype = :numeric
        @ref = 0
        if not @rmdata.is_a?(Numeric) then
          raise ArgumentError, ":chunkwise needs rmdata to be a positive number"
        end
      else
        raise ArgumentError, "readmode #{@readmode.inspect} is unknown/unimplemented"
    end
  end

  def getchunk
    case @readmode
      when :linewise then
        begin
          return @ref.next
        rescue StopIteration
          return nil
        end
      when :chunkwise then
        @ref += 1
        return @handle.read(@rmdata)
    end
    return nil
  end

  def each(&block)
    while true do
      val = getchunk
      if val.nil? then
        break
      else
        block.call(val)
      end
    end
  end
end

class RbGrep
  attr_accessor :readmode

  def initialize(fh, readmode=DEFAULT_READMODE, rmdata=1024)
    @reader = IOChunkReader.new(fh, readmode, rmdata)
  end

  def each(rxobj, &block)
    @reader.each do |chunk|
      result = chunk.match(rxobj)
      if result then
        block.call(result)
      end
    end
  end
end

###################################################
### this is turning convoluted quick! who knew. ###
###################################################

def print_filename(filename, fh, opts, hlen)
  if (opts.nofilenames == false) then
    if (hlen > 1) then 
      $stdout.printf("%s:", filename)
      if opts.printlinenumber == true then
        $stdout.printf("%d:", fh.lineno)
      end
      $stdout.write(" ")
    end
  end
end

def print_matchdata(filename, fh, matchedstr, opts, hlen)
  print_filename(filename, fh, opts, hlen)
  $stdout.puts(matchedstr)
end


def print_namedgroups(filename, fh, match, opts, hlen)
  ## begin namedgroups
  if not opts.namedgroups.empty? then
    if not match.names.empty? then
      opts.namedgroups.each do |name|
        if match.names.include?(name) then
          print_matchdata(filename, fh, match[name], opts, hlen)
        else
          $stderr.printf("error: name %p not in named captures\n", name)
        end
      end
    end
  end
  ## end namedgroups
end

def print_anongroups(filename, fh, match, opts, hlen)
  ## begin anongroups
  if not opts.anongroups.empty? then
    if not match.captures.empty? then
      opts.anongroups.each do |id|
        if id <= match.captures.length then
          print_matchdata(filename, fh, match[id], opts, hlen)
        else
          $stderr.printf("id #%d larger than length of anoncaptures (%d)", id, match.captures.length)
        end
      end
    end
  end
  ## end anongroups
end

def print_generic(filename, fh, match, opts, hlen)
  #print_matchdata(filename, fh, match.inspect, opts, hlen)
  match.to_a.each do |data|
    print_matchdata(filename, fh, data, opts, hlen)
  end
end

def do_rbgrep(pattern, handles, opts)
  hlen = handles.length
  rxobj = Regexp.compile(pattern, opts.rxflags)
  handles.each do |fhpair|
    begin
      handle, filename, shouldclose = fhpair
      rbg = RbGrep.new(handle)
      rbg.each(rxobj) do |match|
        if (not opts.namedgroups.empty?) || (not opts.anongroups.empty?) then
          print_namedgroups(filename, handle, match, opts, hlen)
          print_anongroups(filename, handle, match, opts, hlen)
        else
          print_generic(filename, handle, match, opts, hlen)
        end
      end
    ensure
      if shouldclose then
        begin
          handle.close
        rescue => e
          $stderr.printf("error while closing %p: (%s) %s\n", filename, e.class, e.message)
        end
      end
    end
  end
end

def do_stdinrbgrep(pattern, opts)
  do_rbgrep(pattern, [[$stdin, "<stdin>", false]], opts)
end

#constants: EXTENDED  FIXEDENCODING  IGNORECASE  MULTILINE  NOENCODING
begin
  opts = OpenStruct.new(
    verbose: false,
    forcestdin: false,
    printlinenumber: true,
    anongroups: [],
    namedgroups: [],
    rxflags: [Regexp::EXTENDED, Regexp::NOENCODING],
  )
  sayverbose = lambda{|fmt, *args|
    if opts.verbose then
      str = sprintf(fmt, *args)
      $stderr.printf("verbose: %s\n", str)
    end
  }
  prs = OptionParser.new{|prs|
    prs.on(nil, "--verbose", "enable verbose output"){|v|
      opts.verbose = true
    }
    prs.on(nil, "--stdin", "force reading from stdin"){|v|
      opts.forcestdin = true
    }
    prs.on("-f", "--nofilename", "do not print filename"){|v|
      opts.nofilenames = true
    }
    prs.on("-r", "--recursive", "search recursively"){|v|
      opts.recursive = true
    }
    prs.on("-i", "--icase", "ignore case"){|v|
      opts.rxflags.push(Regexp::IGNORECASE)
    }
    prs.on("-e", "--extended-regex", "use extended regex"){|v|
      opts.rxflags.push(Regexp::EXTENDED)
    }
    prs.on("-a<n>", "--at=<n>", "print match group at <n>"){|v|
      opts.anongroups.push(v.to_i)
    }
    prs.on("-n<name>", "--named=<name>", "print named match group <name>"){|v|
      opts.namedgroups.push(v)
    }
  }
  prs.parse!
  if ARGV.empty? then
    $stderr.puts(prs.help)
    exit(1)
  else
    rawpattern = ARGV.shift
    if ARGV.empty? && (not opts.recursive) then
      if (($stdin.tty?) && (not opts.forcestdin)) then
        $stderr.puts("only regular expression given, with no files, and no stdin input!")
        $stderr.puts("nothing to do. aborting")
        exit(1)
      else
        do_stdinrbgrep(rawpattern, opts)
      end
    else
      # explicitly check files/dirs, because
      # open() (the system call, not File.open) will gladly
      # open directories as files on Linux, and fopen, or whatever ruby uses,
      # doesn't seem to check whether or not the path is an
      # actual readable file or not ...
      # so it's boilerplate, basically.
      files = []
      handles = []
      if opts.recursive then
        dirs = []
        # emulate '-r' behavior of grep when no explicit directory was named
        if ARGV.empty? then
          dirs.push(".")
        else
          ARGV.each do |dirn|
            if not File.directory?(dirn) then
              $stderr.printf("error: --recursive: not a directory: %p\n", dirn)
            else
              dirs.push(dirn)
            end
          end
        end
        # Find is not exactly fast, but as good as it gets atm.
        dirs.each do |dirn|
          Find.find(dirn) do |path|
            if File.file?(path) then
              files.push(path)
            end
          end
        end
      else
        files.push(*ARGV)
      end
      files.each do |fname|
        if File.file?(fname) then
          begin
            fh = File.open(fname, "rb")
            handles.push([fh, fname, true])
          rescue => err
            $stderr.printf("error opening %p: (%s) %s\n", fname, err.class, err.message)
          end
        else
          $stderr.printf("error: %p is not a file\n", fname)
        end
      end
      do_rbgrep(rawpattern, handles, opts)
    end
  end
end
