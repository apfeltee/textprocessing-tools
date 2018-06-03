#!/usr/bin/ruby --disable-gems

##
## synopsis: read lines from input, and print them in reverse order.
##    i.e.:
##
##      input:
##        red
##        green
##        blue
##        yellow
##        purple
##
##      output:
##        purple
##        yellow
##        blue
##        green
##        red
##

require "optparse"

# is there a faster way to do this?
def revlines(iolike, outfile, sep: $/)
  cache = []
  iolike.each_line do |l|
    cache.push(l)
  end
  cache.reverse.each do |l|
    outfile.write(l)
  end
end

def usage(code=1)
  selfname = File.basename($0)
  printf("usage:\n")
  printf("  %s [<file1> <file2> ...]\n", selfname)
  printf("  some-program | %s\n", selfname)
  puts()
  exit(code)
end

begin
  prs = OptionParser.new{
  }
  prs.parse!
  $stdout.sync = true
  if ARGV.empty? then
    if (not $stdin.tty?) then
      revlines($stdin, $stdout)
    else
      usage
    end
  else
    ARGV.each do |file|
      File.open(file, "rb") do |fh|
        revlines(iolike, $stdout)
      end
    end
  end
end
