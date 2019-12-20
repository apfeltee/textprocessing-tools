#!/usr/bin/ruby

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
require "iconv"

INPUT_ENCODING  = "UTF-16"
OUTPUT_ENCODING = "UTF-8"

def decode(str)
  begin
    #line.encode!("utf-8")
    return Iconv.iconv("utf-8", "utf-16", line).first
    #return line.force_encoding("utf-16").encode("utf-8")
  rescue => ex
    return str
  end
end

def utf16fix(filename, infh, outfh, **opts)
  infh.set_encoding(INPUT_ENCODING, OUTPUT_ENCODING)
  begin
    outfh.write(infh.read)
  #rescue Encoding::InvalidByteSequenceError => err
  rescue => err
    #if opts[:force] then
      # try again, but remove input encoding.
      # this is also very likely to not work at all.
      # perhaps might work with iconv?
      #infh.set_encoding(nil, nil)
      #return utf16fix(infh, outfh, **opts)
    #end
    $stderr.printf("error: %p: (%s) %s -- file unchanged\n", filename, err.class.name, err.message)
    return false
  end
  return true
end


begin
  opts = {}
  prs = OptionParser.new{|prs|
    prs.banner = "usage: #{File.basename($0)} [-n] [<file ...>]"
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
      utf16fix("<stdandard-input>", $stdin, $stdout, **opts)
    end
  else
    ARGV.each do |file|
      omode = "rb"
      infile = file
      outfile = $stdout
      success = false
      if opts[:inplace] then
        outfile = Tempfile.open
        #$stderr.puts("inplace: temporary file is at #{outfile.path.dump}")
      end
      begin
        File.open(infile, omode) do |fh|
          success = utf16fix(infile, fh, outfile, **opts)
        end
      ensure
        if opts[:inplace] then
          outfile.close unless outfile.closed?
          begin
            if success then
              FileUtils.mv(outfile.path, file)
            end
          ensure
            outfile.delete
          end
        end
      end
    end
  end
end


