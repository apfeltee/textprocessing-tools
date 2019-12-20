#!/usr/bin/ruby --disable-gems

require "csv"
require "json"
require "optparse"
require "ostruct"

class BaseGenerator
  def initialize(opts)
    @opts = opts
    @out = @opts.outfile
  end

  def writeheader
  end

  def writefooter
  end

  def handle(chunk)
  end
end

class GenerateJSON < BaseGenerator
  def writeheader
    @out.puts("[")
  end

  def writefooter
    @out.puts("]")
  end

  def handle(chunk)
    #begin
      @out.write(JSON.pretty_generate(chunk))
      @out.puts(",")
    #rescue Interrupt
      #return
    #end
  end
end

class GenerateText < BaseGenerator
  def getrealindex(chunk, idx)
    # use key as-is if chunk is a hash
    if chunk.is_a?(Hash) then
      # if the key exists, return that
      if chunk.has_key?(idx) then
        return idx
      else
        # ... otherwise, if ignorecase was specified, try
        # to check keys by ignoring case sensitivity (sic) ...
        if @opts.ignorecase then
          ridx = idx.downcase
          chunk.keys.each do |keyname|
            # so if it matches, we're good to go
            if keyname.downcase == ridx then
              return keyname
            end
          end
        end
        # either the key doesn't exist, or it does BUT ignorecase wasn't
        # specified: either way, it's nil
        return nil
      end
    end
    # otherwise, return as numeric index
    return idx.to_i
  end

  def handle(chunk)
    realidx = getrealindex(chunk, @opts.text_index)
    if not realidx.nil? then
      @out.puts(chunk[realidx])
    end
  end
end

def parse(path, opts, &block)
  CSV.foreach(path, headers: opts.useheaders) do |row|
    if opts.useheaders then
      h = row.to_h
      isnull = false
      h.each do |k, v|
        if opts.nonull then
          if v.nil? then
            isnull = true
          end
        end
      end
      if not isnull then
        block.call(h)
      end
    else
      block.call(row)
    end
  end
end

def get_generator(opts)
  case opts.generate
    when "json" then
      return GenerateJSON.new(opts)
    when "text"
      return GenerateText.new(opts)
    else
      $stderr.printf("error: unhandled/unimplemented generator %p\n", opts.generate)
      exit(1)
  end
end

def handle(path, opts)
  gen = get_generator(opts)
  gen.writeheader
  begin
    parse(path, opts) do |chunk|
      gen.handle(chunk)
    end
  ensure
    gen.writefooter
  end
end

begin
  opts = OpenStruct.new({
    generate: "json",
    outfile: $stdout,
    ignorecase: true,
    headers: false,
  })
  prs = OptionParser.new{|prs|
    prs.on("-n", "--no-null", "exclude empty values"){|v|
      opts.nonull = true
    }
    prs.on("-j", "--json", "generate json"){|_|
      opts.generate = "json"
    }
    prs.on("-t<index>", "--text=<index>", "generate (extract) text from <index>"){|idx|
      opts.generate = "text"
      opts.text_index = idx
    }
  }
  prs.parse!
  if ARGV.empty? then
    puts(prs.help)
    exit(1)
  else
    ARGV.each do |arg|
      handle(arg, opts)
    end 
  end
end
