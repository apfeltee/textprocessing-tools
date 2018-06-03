#!/usr/bin/ruby

require "optparse"
require "http"
require "nokogiri"

HTMLTEXT_DEFAULT_SELECTOR = "html"
# how about <script>, and <style>?
HTMLTEXT_DEFAULT_REMOVEME = %w(style)

def error(fmt, *args)
  msg = sprintf(fmt, *args)
  $stderr.printf("ERROR: %s\n", msg)
  exit(1)
end

def ishtml?(response, item)
  if (item.match(/^file/i) && item.match(/\.html?/i)) then
    # assume true, since there isn't really a sane way to check
    return true
  else
    if item.match(/^https?/) then
      return (response["content-type"] =~ /^text\/(html|xml)/i)
    end
  end
  return false
end

def getsource(item)
  if item.match(/^(https?|ftps?|rsync|file):\/\//i) then
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
  else
    if File.file?(item) then
      return File.read(item)
    else
      error("not an URL or file: %p", item)
    end
  end
end

def htmltext(item, opts)
  out = opts[:outfh]
  mode = opts[:mode]
  selector = opts[:selector]
  removeme = opts[:removeme]
  src = getsource(item)
  doc = Nokogiri::HTML(src)
  removeme.each do |sel|
    doc.css(sel).each do |elem|
      elem.remove
    end
  end
  doc.css(selector).each do |elem|
    elem.content.each_line do |line|
      line.scrub!
      line.gsub!(/[\u00A0]/, "")
      #line.rstrip!
      stripped = line.rstrip
      if not stripped.empty? then
        case mode
          when "normal" then
            out.puts(line)
          when "dump" then
            out.printf("%p\n", line)
          else
            raise sprintf("unsupported mode %p", mode)
        end
      end
    end
  end
end

begin
  opts = {
    outfh: $stdout,
    mode: "normal",
    selector: HTMLTEXT_DEFAULT_SELECTOR,
    removeme: HTMLTEXT_DEFAULT_REMOVEME,
  }
  mustclose = false
  prs = OptionParser.new{|prs|
    prs.on("-s<val>", "--selector=<val>", "use <val> as CSS selector (default: #{opts[:selector].dump})"){|s|
      opts[:selector] = s
    }
    prs.on("-o<file>", "--out=<file>", "write output to <file>"){|s|
      opts[:outfh] = File.open(s, "wb")
      mustclose = true
    }
    prs.on("-m<mode>", "--mode=<mode>", "use <mode> for output"){|s|
      opts[:mode] = s
    }
    prs.on("-e<selector>", "--remove=<selector>", "remove any element matching <selector>"){|s|
      opts[:removeme].push(s)
    }
  }
  prs.parse!
  begin
    if ARGV.empty? then
      $stdout.puts(prs.help)
      exit(1)
    end
    ARGV.each do |url|
      htmltext(url, opts)
    end
  ensure
    if mustclose then
      outfh.close
    end
  end
end


