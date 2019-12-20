#!/usr/bin/ruby

require "uri"
require "ostruct"
require "optparse"
require "http"
require "nokogiri"

=begin
request_uri
hostname
absolute
route_from
component_ary
route_to
opaque
userinfo
registry
fragment
find_proxy
coerce
normalize
merge
query
host
select
user
path
component
scheme
port
password
=end

def fixpath(arg, prefix: "/cygdrive/")
  if arg.match(/^\/cygdrive/i) then
    buf = String.new
    prefix = "/cygdrive/"
    tmp = arg[prefix.length .. -1].chars
    letter = tmp.shift
    buf = "#{letter}:#{tmp.join}"
    return fixpath(buf, prefix: prefix)
  end
  return arg#.gsub("/", "\\\\")
end



class HTMLUrls
  def initialize(urlstr, opts)
    @opts = opts
    @baseuri = @opts.baseuri
    @baseuristr = @baseuri.to_s
    @data = get_data(urlstr)
    @doc = Nokogiri::HTML(@data)
  end

  def get_data(urlstr)
    if @opts.isfile then
      return File.read(urlstr)
    end
    return HTTP.follow(@opts.http_follow).get(urlstr).body.to_s
  end

  def fmturl(piece)
    # would match "http://", "https://", "ftp://", etc
    if piece.match(/^(\w+):\/\//) then
      return piece
    elsif piece[0] == '/' then
      # urls starting with '//' are "scheme relative", i.e.,
      # intended to "inherit" the scheme of the base URI
      if piece[1] == '/' then
        return sprintf("%s:%s", @baseuri.scheme, piece)
      end
      tmp = sprintf("%s://%s", @baseuri.scheme, @baseuri.host)
      if (@baseuri.port != nil) then
        if ((@baseuri.port != 80) && (@baseuri.port != 443)) then
          tmp += sprintf(":%d", @baseuri.port)
        end
      end
      tmp += piece
      newuri = URI.parse(tmp)
      # the idea is to combine the query of the base URI.
      # but this is probably not a good idea, because it may mean repeating values...
=begin
      if (newuri.query != nil) then
        if @baseuri.query != nil then
          tmp += '&'
        else
          tmp += '?'
        end
        tmp += @baseuri.query
      end
=end
      return tmp
    else
      return File.join(@baseuristr, piece)
    end
    $stderr.printf("fmturl: cannot figure out how to join/parse piece %p from urlbase %p\n", piece, @opts.baseuri)
    return nil
  end

  def walk(&block)
    @doc.css("a").each do |node|
      href = node["href"]
      next if (href == nil)
      next if (href == "")
      next if (href.match(/^javascript:/))
      absurl = fmturl(href)
      if absurl != nil then
        block.call(absurl)
      end
    end
  end
end

def handle(arg, opts)
  if arg.match(/^https?:\/\//i) then
    opts.isfile = false
    opts.baseuri = URI.parse(arg)
  end
  if opts.isfile then
    fileabs = fixpath(File.absolute_path(arg))
    filedir = File.dirname(fileabs)
    #$stderr.printf("fileabs=%p, filedir=%p\n", fileabs, filedir)
    opts.baseuri = URI.parse(sprintf("file:///%s", filedir.gsub(/^\//, "")))
  end
  HTMLUrls.new(arg, opts).walk do |url|
    $stdout.puts(url)
    $stdout.flush
  end
end

begin
  opts = OpenStruct.new({
    isfile: true,
    http_follow: true,
  })
  OptionParser.new{|prs|
  }
  ARGV.each do |arg|
    handle(arg, opts)
  end
end
