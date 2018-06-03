#!/usr/bin/ruby --disable-gems

require "ostruct"
require "optparse"

class SubstHandler
  def initialize(rx, opts)
    @regex = rx
    @opts = opts
    @callback = nil
    if not @opts.callbackcode.nil? then
      @callback = build_callback
    end
  end

  def build_callback
    rawcode = sprintf("lambda{|match, *rest|\n %s \n}\n", @opts.callbackcode)
    $stderr.printf("rawcode=%p\n", rawcode)
    return eval(rawcode)
  end

  def subst(oldline, replacement)
    if @callback.nil? then
      return oldline.gsub(@regex, replacement)
    end
    return oldline.gsub(@regex, &@callback)
  end
end

begin
  opts = OpenStruct.new({
    modcount: 0,
    regflags: 0,
    callbackcode: nil,
    test: false,
    noregex: false,
    inplace: false,
    mustclose_out: false,
    mustclose_in: false,
    outfile: $stdout,
    infile: $stdin,
  })
  prs = OptionParser.new{|prs|
    prs.on("-o<file>", "--output=<file>", "write output to <file>"){|path|
      fh = File.open(path, "wb")
      opts.mustclose_out = true
      opts.outfile = fh
    }
    prs.on("-i", "--icase", "create case-insensitive expression"){|_|
      opts.regflags |= Regexp::IGNORECASE
    }
    prs.on("-n", "--noencoding", "ignore encoding (invalid or otherwise!)"){|_|
      opts.regflags |= Regexp::NOENCODING
    }
    prs.on("-x", "--extended", "use extended regexp flag"){|_|
      opts.regflags |= Regexp::EXTENDED
    }
    prs.on("-r", "--rawstrings", "do not build a regular expression; instead use raw strings"){|_|
      opts.noregex = true
    }
    prs.on("-e<s>", "--evalcode=<s>", "eval ruby code <s> as block for #gsub"){|str|
      opts.callbackcode = str
    }
    prs.on("-t", "--test", "test only"){|_|
      opts.test = true
    }
  }
  prs.parse!
  pattern = ARGV.shift
  replacement = (ARGV.shift || "")
  begin
    if pattern.nil? then
      $stderr.puts("error: must provide pattern!")
      exit(1)
    else
      rex = (opts.noregex ? pattern : Regexp.new(pattern, opts.regflags))
      hnd = SubstHandler.new(rex, opts)
      $stderr.printf("compiled expression: %p\n", rex)
      opts.infile.each_line do |oldline|
        newline = hnd.subst(oldline, replacement)
        opts.modcount += ((newline != oldline) ? 1 : 0)
        opts.outfile.write(opts.test ? oldline : newline)
      end
    end
  ensure
    $stderr.printf("modified %d line(s)\n", opts.modcount)
    if opts.mustclose_out then
      opts.outfile.close
    end
  end
end
