#!/usr/bin/ruby

#Example taken from the REXML tutorial (http://www.germane-software.com/software/rexml/docs/tutorial.html)

require "ostruct"
require "optparse"
require "pp"
require "rexml/document"

=begin
#create the REXML Document from the string (%q is Ruby's multiline string, everything between the two @-characters is the string)
doc = REXML::Document.new(
        %q@<inventory title="OmniCorp Store #45x10^3">
             ...
           </inventory>
          @
                          )
# The invisibility cream is the first <item>
invisibility = REXML::XPath.first( doc, "//item" )
# Prints out all of the prices
REXML::XPath.each( doc, "//price") { |element| puts element.text }
# Gets an array of all of the "name" elements in the document.
names = REXML::XPath.match( doc, "//name" )

=end

class XPathProg
  attr_accessor :opts, :filename, :document

  def initialize(opts)
    @opts = opts
  end

  def load_string(strdata, filename)
    @filename = filename
    @document = REXML::Document.new(strdata)
  end

  def load_file(filepath)
    File.open(filepath, "rb") do |fh|
      load_string(fh.read, filepath)
    end
  end

  def load_stdin()
    load_string($stdin.read, "<stdin>")
  end
end

def main(expr, xp)
  ret = REXML::XPath.send(xp.opts.use_method, xp.document)
  if xp.opts.dump then
    pp ret
  else
    ret.each do |val|
      p val
    end
  end
end

begin
  opts = OpenStruct.new({
    use_method: "match",
  })
  OptionParser.new{|prs|
    prs.on("-m", "--match", "use .match()"){|_|
      opts.use_method = "match"
    }
    prs.on("-e", "--each", "use .each()"){|_|
      opts.use_method = "each"
    }
  }.parse!
  xp = XPathProg.new(opts)
  expr = ARGV.shift
  if expr.nil? then
    $stderr.printf("ERROR: first argument must be an xpath expression!\n")
  else
    if ARGV.empty? then
      xp.load_stdin
      main(expr, xp)
    else
      ARGV.each do |file|
        xp.load_file(file)
        main(expr, xp)
      end
    end
  end
end

