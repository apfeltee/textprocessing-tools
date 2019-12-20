#!/usr/bin/ruby

ALPHABET = {
  "a"      => "Alfa",
  "b"      => "Bravo",
  "c"      => "Charlie",
  "d"      => "Delta",
  "e"      => "Echo",
  "f"      => "Foxtrot",
  "g"      => "Golf",
  "h"      => "Hotel",
  "i"      => "India",
  "j"      => "Juliett",
  "k"      => "Kilo",
  "l"      => "Lima",
  "m"      => "Mike",
  "n"      => "November",
  "o"      => "Oscar",
  "p"      => "Papa",
  "q"      => "Quebec",
  "r"      => "Romeo",
  "s"      => "Sierra",
  "t"      => "Tango",
  "u"      => "Uniform",
  "v"      => "Victor",
  "w"      => "Whiskey",
  "x"      => "X-ray",
  "y"      => "Yankee",
  "z"      => "Zulu",
  "0"      => "Zero",
  "1"      => "One",
  "2"      => "Two",
  "3"      => "Three",
  "4"      => "Four",
  "5"      => "Five",
  "6"      => "Six",
  "7"      => "Seven",
  "8"      => "Eight",
  "9"      => "Nine",
  #"100"    => "Hundred",
  #"1000"   => "Thousand",
  "-"      => "Dash",
  "."      => "Period",
}

# special characters that have no analogues in the nato alphabet, but
# usually still matter in terms of formatting
NOSPACE = [
  "(",
  ")",
  "[",
  "]",
  "{",
  "}",
  "<",
  ">",
  ",",
  ";",
  "+",
  "/",
  " ",
  "\"",
  "'",
  "\\",
  "~",
  "&",
  "%",
]

def fmt(ch, nch)
  dch = ch.downcase
  if ALPHABET.key?(dch) then
    $stdout.write(ALPHABET[dch])
    if (nch != nil) && NOSPACE.include?(nch) then
      #$stdout.write(nch)
    else
      $stdout.write(" ")
    end
  else
    $stdout.write(ch)
  end
end

begin
  $stdin.each_char.each_cons(2) do |ch, nch|
    #p [ch, nch]
    if (ch == '\r') then
      next
    end
    fmt(ch, nch)
  end
  $stdout.puts
end

