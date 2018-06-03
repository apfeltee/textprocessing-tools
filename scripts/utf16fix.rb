#!/usr/bin/ruby --disable-gems

# to -> from
# Iconv.new("US-ASCII//IGNORE", "UTF-16LE")
##
## synopsis: turns utf16 into utf8 (if file contains non-ascii), or
##    into plain ascii. particularly useful for files that are created
##    by windows commands, like cmd.exe, powershell, etc.
##

require "tempfile"
require "fileutils"
require "optparse"

INPUT_ENCODING  = "UTF-16LE"
OUTPUT_ENCODING = "UTF-8"

def utf16fix(infh, outfh, **opts)
  infh.set_encoding(INPUT_ENCODING, OUTPUT_ENCODING)
  begin
    infh.each_line.with_index do |line, idx|
      # may seem lazy, but prevents having to read the whole file
      if (idx == 0) then
        # utf8 bom
        if not opts[:keep_bom] then
          if line.start_with?("\xEF\xBB\xBF") then
            # important:
            # it's a codepoint, which counts as one character in utf8!
            line = line.slice(1, line.length)
          # utf16 bom (*shouldn't* happen ...)
          elsif line.start_with?("\xFF\xFE") then
            # ruby treats utf16 like ordinary bytes
            line = line.slice(2, line.length)
          end
        end
      end
      opts.each do |k, _|
        case k
          when :crlf_to_lf then
            #line.gsub!(/\r/, "")
            #if not line.match(/\n$/) then
              #line += "\n"
            #end
            line.rstrip!
        end
      end
      begin
        if opts[:crlf_to_lf] then
          outfh.puts(line)
        else
          outfh.write(line)
        end
        outfh.flush
      rescue Errno::EPIPE => e
        # happens when output is being piped to programs that
        # exit before the pipe finished, but in this context,
        # this is a non-error.
        # for example, when utf16fix is being piped to the
        # 'head' command.
      end
    end
  rescue Encoding::InvalidByteSequenceError => err
    if opts[:force] then
      # try again, but remove input encoding.
      # this is also very likely to not work at all.
      # perhaps might work with iconv?
      infh.set_encoding(nil, nil)
      return utf16fix(infh, outfh, **opts)
    end
    $stderr.puts("error: (#{err.class}) #{err.message}")
    $stderr.puts("(input file probably isn't encoded as UTF-16)")
  end
end


begin
  opts = {crlf_to_lf: true}
  prs = OptionParser.new{|prs|
    prs.banner = "usage: #{File.basename($0)} [-n] [<file ...>]"
    prs.on("-n", "--[no-]convert-crlf", "convert cr-lf (\\r\\n) to lf (\\n)"){|v|
      opts[:crlf_to_lf] = v
    }
    prs.on("-k", "--[no-]keep-bom", "keep byte-order mark"){|v|
      opts[:keep_bom] = v
    }
    prs.on("-f", "--[no-]force", "continue on encoding errors (may cause undefined behaviour!)"){|v|
      opts[:force] = v
    }
    prs.on("-i", "--[no-]inplace", "modify file inplace"){|v|
      opts[:inplace] = v
    }
  }
  prs.parse!
  if ARGV.empty? then
    if $stdin.tty? then
      $stderr.puts(prs.help)
      exit(1)
    else
      utf16fix($stdin, $stdout, **opts)
    end
  else
    ARGV.each do |file|
      omode = "rb"
      infile = file
      outfile = $stdout
      if opts[:inplace] then
        outfile = Tempfile.open
        $stderr.puts("inplace: temporary file is at #{outfile.path.dump}")
      end
      begin
        File.open(infile, omode) do |fh|
          utf16fix(fh, outfile, **opts)
        end
      ensure
        if opts[:inplace] then
          outfile.close unless outfile.closed?
          begin
            FileUtils.mv(outfile.path, file, verbose: true)
          ensure
            outfile.delete
          end
        end
      end
    end
  end
end


