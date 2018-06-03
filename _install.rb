#!/usr/bin/ruby --disable-gems

$userbindir = File.join(ENV["HOME"], "bin")

Dir.glob("./scripts/*.rb") do |scr|
  path = File.absolute_path(scr)
  basename = File.basename(scr)
  exename = File.basename(basename, File.extname(basename))
  destname = File.join($userbindir, exename)
  cmd = ["ln", "-sfv", path, destname]
  system(*cmd)
end
