#!/usr/bin/ruby

require "optparse"
require "ostruct"

def escapecp(codepoint)
  return sprintf("&#x%03X;", codepoint)
end

def escapeio(iothing, &block)
  iothing.each_byte.with_index do |b, i|
    block.call(escapecp(b), i)
  end
end

def escapeio_stdout(iothing, out, opts)
  ctr = 0
  out.write(opts.before)
  escapeio(iothing) do |rt, i|
    out.write(rt)
    ctr += 1
    if not opts.linemax.nil? then
      if ((ctr + 1) == opts.linemax) then
        out.write("\n")
        ctr = 0
      end
    end
  end
  out.write(opts.after)
  if (opts.addnewline) then
    out.write("\n")
  end
end

begin
  $stdout.sync = true
  opts = OpenStruct.new(
    before: "",
    after: "",
    linemax: nil,
    addnewline: true,
  )
  prs = OptionParser.new{|prs|
    prs.on("-b<str>", "--before=<str>", "text or html to be written before encoded text"){|v|
      opts.before = v
    }
    prs.on("-a<str>", "--after=<str>", "text or html to be written after encoded text"){|v|
      opts.after = v
    }
    prs.on("-w", "--wrappre", "wrap encoded text in <pre></pre>"){|v|
      opts.before = "<pre>"
      opts.after = "</pre>"
    }
  }
  prs.parse!
  if ARGV.empty? then
    if !$stdin.tty? then
      escapeio_stdout($stdin, $stdout, opts)
    else
      puts(prs.help)
      exit(1)
    end
  else
    ARGV.each do |f|
      File.open(f, "rb") do |fh|
        escapeio_stdout(fh, $stdout, opts)
      end
    end
  end
end
