#!/usr/bin/ruby

require "open3"
require "optparse"
require "http"
require "nokogiri"

HTMLTEXT_DEFAULT_SELECTOR = "html"
# entities that typically contain "text" that the browser
# typically does not represent as such.
# htmltext doesn't interpret css, nor js, so there's no
# point in keeping them
HTMLTEXT_DEFAULT_REMOVEME = %w(style script)

class LessPipe
  def initialize
    @stdin, @thr = Open3.pipeline_w("less")
  end

  def close
    @stdin.close
    return @thr
  end

  def write(str)
    @stdin.write(str)
  end

  def pipe_file(path)
    File.open(path, "rb") do |fh|
      pipe_io(fh)
    end
  end

  def pipe_io(iohnd)
    iohnd.each_line do |line|
      write(line)
    end
  end
end

def error(fmt, *args)
  msg = sprintf(fmt, *args)
  $stderr.printf("ERROR: %s\n", msg)
  exit(1)
end

def ishtml?(response, item)
  if (item.match(/^file/i) && item.match(/\.s?html?/i)) then
    # assume true, since there isn't really a sane way to check
    return true
  else
    if item.match(/^https?:/) then
      return (response["content-type"] =~ /^text\/(html|xml)/i)
    end
  end
  return false
end


class HTMLText
  def initialize(opts)
    @opts = opts
  end

  def dbg(fmt, *a, **kw)
    if @opts.debug then
      $stderr.printf("%s", sprintf(fmt, *a, **kw))
    end
  end

  def gethttp(url)
    resp = HTTP.follow(true).get(item)
    if resp.code == 200 then
      if ishtml?(resp, item) then
        return resp.body.to_s
      else
        if item.match(/^https?/) then
          ctype = resp["content-type"]
          error("URL responded with non-html content type %p", ctype)
        else
          error("URL %p didn't seem to be a HTML document", item)
        end
      end
    else
      error("URL responded with HTTP code %d", resp.code)
    end
  end

  def getsource(item)
    if item.nil? then
      return $stdin.read
    elsif item.is_a?(String) then
      if item.match(/^(https?|ftps?|rsync|file):\/\//i) then
        return gethttp(item)
      else
        if File.file?(item) then
          return File.read(item)
        else
          error("not an URL or file: %p", item)
        end
      end
    else
      # this really shouldn't occur, methinks.
      error("unrecognized source %p", item)
    end
  end

  def htmltext(item, &block)
    out = @opts.outfh
    mode = @opts.mode
    selector = @opts.selector
    removeme = @opts.removeme
    wantlf = @opts.newline
    # retrieve raw html source
    src = getsource(item)
    # construct dom
    doc = Nokogiri::HTML(src)
    # remove elems specified via :removeme
    removeme.each do |sel|
      doc.css(sel).each do |elem|
        elem.remove
      end
    end
    # now iterate the remainder
    tree = (
      # doc.css(selector)
      ## doc.traverse(&b)
      doc.search('*')
    )
    #doc.css(selector).each do |elem|
    tree.each do |elem|
      dbg("-- processing node %p ... ", elem.name)
      if not elem.respond_to?(:content) then
        dbg("skipping: has no content")
      end
      # Node#content is the text of the node, i.e., HTMLElement::innerHTML
      elem.content.each_line do |line|
        line.scrub!
        # who knows why this particular character keeps popping up...
        line.gsub!(/[\u00A0]/, "")
        stripped = line.rstrip
        if not stripped.empty? then
          case mode
            when "normal" then
              block.call(line)
            when "dump" then
              block.call(sprintf("%p\n", line))
            else
              raise sprintf("unsupported mode %p", mode)
          end
          if wantlf then
            block.call("\n")
          end
        end
      end
      dbg(" - done\n", elem.name)
    end
  end

  def mkwriter
    if @opts.wantless then
      return LessPipe.new
    else
      return @opts.outfh
    end
  end

  def dourl(url)
    out = mkwriter
    begin
      htmltext(url) do |chunk|
        out.write(chunk)
      end
    ensure
      out.close
    end
  end

end


begin
  opts = OpenStruct.new({
    newline: false,
    outfh: $stdout,
    mode: "normal",
    selector: HTMLTEXT_DEFAULT_SELECTOR,
    removeme: HTMLTEXT_DEFAULT_REMOVEME,
  })
  mustclose = false
  prs = OptionParser.new{|prs|
    prs.on("-s<val>", "--selector=<val>", "use <val> as CSS selector (default: #{HTMLTEXT_DEFAULT_SELECTOR.dump})"){|s|
      opts.selector = s
    }
    prs.on("-o<file>", "--out=<file>", "write output to <file>"){|s|
      opts.outfh = File.open(s, "wb")
      mustclose = true
    }
    prs.on("-m<mode>", "--mode=<mode>", "use <mode> for output [valid: normal, dump]"){|s|
      opts.mode = s
    }
    prs.on("-e<selector>", "--remove=<selector>", "remove any element matching <selector>"){|s|
      opts.removeme.push(s)
    }
    prs.on("-l", "--less", "show output via less"){|_|
      opts.wantless = true
    }
    prs.on("-n", "--newline", "add linefeed after every element"){
      opts.newline = true
    }
    prs.on("-d", "--debug", "enable debug messages"){
      opts.debug = true
    }
  }
  prs.parse!
  ht = HTMLText.new(opts)
  begin
    if ARGV.empty? then
      if $stdin.tty? then
        $stdout.puts(prs.help)
        exit(1)
      else
        ht.dourl(nil)
      end
    else
      ARGV.each do |url|
        ht.dourl(url)
      end
    end
  ensure
    if mustclose then
      opts.outfh.close
    end
  end
end


