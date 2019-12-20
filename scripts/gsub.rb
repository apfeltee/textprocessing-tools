#!/usr/bin/ruby -w

require "ostruct"
require "optparse"

def get_filename_for(io)
  begin
    return File.readlink("/proc/self/fd/#{io.fileno}")
  rescue
    return nil
  end
end

class GSubst
  attr_reader :errcount

  def initialize(opts)
    @opts = opts
    @pairsep = @opts.pairseparator
    @pairs = []
    @rxhash = {}
    @filebuffer = nil
    @errcount = 0
    @totals = 0
    # i, x, g, m, etc.
    # no need to use Regexp::* for this (kinda cool tbh)
    @rxflags = (if @opts.regexflags.empty? then nil else @opts.regexflags end)
    @outhandle = $stdout
    if @opts.outputfile != nil then
      @outhandle = File.open(@opts.outputfile, "w")
    end
  end

  def msg(fmt, *a)
    $stderr.printf("-- %s\n", sprintf(fmt, *a))
  end

  def warn(fmt, *a)
    $stderr.printf("!! %s\n", sprintf(fmt, *a))
  end

  def add_raw_pair(str)
    if str.include?(@pairsep) then
      @pairs.push(str)
    else
      #$stderr.printf("ERROR: substitution pattern must be '<pattern>%s<replacement>', but got instead: %p\n", @pairsep, str)
      #exit(1)
      warn("pattern %p doesn't have %p -- assuming nil", str, @pairsep)
      @pairs.push(str + "=")
    end
  end

    ## todo:
    ## this needs to be ... better. like, way better
  def split_and_populate(pairstr)
    rawrx, *rest = pairstr.split(@pairsep, -1)
    rawrep = rest.join(@pairsep)
    rxstrbuf = []
    if @opts.autoboundary then
      rxstrbuf.push('\b')
    end
    rxstrbuf.push(rawrx)
    if @opts.autoboundary then
      rxstrbuf.push('\b')
    end
    # old habits die hard: yeah, i'm forwarding. whatcha gonna do about it
    realrx = nil
    begin
      realrx = Regexp.new(rxstrbuf.join, @rxflags)
    rescue => ex
      warn("ERROR: failed to compile %p (from %p): (%s) %s", rawrx, pairstr, ex.class.name, ex.message)
      @errcount += 1
      return
    end
    msg("compiled: %p -> %p", realrx, rawrep)
    @rxhash[realrx] = rawrep
  end

  def compile_regex_hash
    @pairs.each do |pair|
      split_and_populate(pair)
    end
  end

  def prepare
    compile_regex_hash
  end

  def finish
    if @opts.outputfile != nil then
      @outhandle.close
    end
  end

  def process_io(fh)
    @filebuffer = fh.read
    fname = get_filename_for(fh)
    @totals = 0
    pre = ""
    if fname != nil then
      pre = sprintf("%p: ", File.basename(fname))
    end
    begin
      @rxhash.each do |rx, rep|
        thismatches = @filebuffer.scan(rx).length
        msg("%sregex %p: %d matches ...", pre, rx, thismatches)
        if thismatches == 0 then
          if @opts.bailnomatch then
            @errcount += 1
            msg(" **** -x: NOTHING MATCHED! stopping.")
            return
          end
        end
        @totals += thismatches
        @filebuffer.gsub!(rx, rep)
      end
    ensure
      msg("%sdid %d total substitutions", pre, @totals)
      if not @opts.inplace then
        if @errcount == 0 then
          @outhandle.write(@filebuffer)
        end
      end
    end
  end

  # needs improvement
  def process_file(filepath)
    begin
      File.open(filepath, "rb") do |fh|
        process_io(fh)
      end
    ensure
      if @opts.inplace then
        if @errcount > 0 then
          warn("refusing to write back to %p, because errors occured", filepath)
        else
          if @totals > 0 then
            File.open(filepath, "wb") do |fh|
              fh.write(@filebuffer)
            end
          else
            msg("nothing modified; no changes made to %p", filepath)
          end
        end
      end
      # cause GC to pick up
      @filebuffer = nil
    end
  end
end

begin
  opts = OpenStruct.new({
    pairseparator: "=",
    regexflags: "",
    autoboundary: false,
    inplace: false,
    files: [],
    outputfile: nil,
    bailnomatch: false,
  })
  OptionParser.new{|prs|
    prs.on("-h", "--help", "show this help and exit"){
      puts(prs.help)
      puts(
        "\n" +
        "example usage:\n" +
        "\n" +
        "   gsub -b FALSE=false < myfile > myupdatedfile\n" +
        "\n" +
        "would replace each instance of 'FALSE' with 'false', with boundary markers (-b)\n" +
        "\n"
      )
      exit(0)
    }
    prs.on("-b", "--boundary", "--autoboundary", "surround pattern with '\\b' (boundary markers)"){
      opts.autoboundary = true
    }
    prs.on("-f<path>", "--file=<path>", "operate on <path> (can be used multiple times)"){|v|
      opts.files.push(v)
    }
    prs.on("-c", "-i", "--caseinsensitive", "case-insensitive regex"){
      opts.regexflags += "i"
    }
    prs.on("-x", "--bail", "bail if a regex does NOT match"){
      opts.bailnomatch = true
    }
    prs.on("-r", "--inplace", "--replace", "when used with option '-f', replace in-place"){
      opts.inplace = true
    }
    prs.on("-o<path>", "--out=<file>", "--output=<file>", "write output to <file> (implies '-r' if <file> is the same file as specified by '-f')"){|v|
      opts.outputfile = v
    }
  }.parse!


  if (opts.outputfile != nil) then
    if (opts.files.length != 0) then
      if (opts.files.length > 1) then
        $stderr.printf("ERROR: option '-o' can only be used with one file (or stdin)!\n")
        exit(1)
      else
        inpf = opts.files[0]
        # silly, but still
        if File.file?(inpf) && File.file?(opts.outputfile) then
          if File.stat(inpf) == File.stat(opts.outputfile) then
            $stderr.printf("WARNING: setting '--inplace', because input and output are the same file\n")
            opts.outputfile = nil
            opts.inplace = true
          end
        end
      end
    end
  end
  gs = GSubst.new(opts)
  if ARGV.empty? then
    $stderr.printf("error: must provide at least one pattern!\n")
    exit(1)
  else
    ARGV.each do |arg|
      if arg.include?(opts.pairseparator) then
        gs.add_raw_pair(arg)
      else
        gs.add_raw_pair(arg)
      end
    end
    gs.prepare
    begin
      if opts.files.empty? then
        if $stdin.tty? then
          $stderr.printf("ERROR: no files specified, and nothing piped!\n")
          exit(1)
        else
          gs.process_io($stdin)
        end
      else
        opts.files.each do |file|
          gs.process_file(file)
        end
      end
    rescue Errno::EPIPE
    ensure
      gs.finish
      exit(gs.errcount == 0)
    end
  end
end

