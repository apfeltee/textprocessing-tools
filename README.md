# text-processing utilities

A collection of scripts that deal with text. Some transform, others extract, others do entirely different things altogether!

What's included:

 + **csv2a.rb**

Transforms CSV files into different formats, or extracts information.  
For example, `cvs2a --json somefile.csv` turns the data of somefile.csv into a JSON file.  
But, `cvsa -tName somefile.csv` prints every record named "Name".  
This is still fairly lacking in features, as I rarely use csv.

 + **gsub.rb**

A somewhat healthier replacement for sed, and/or `perl -pe 's/.../.../g'`.  
It compiles a given pattern into a regular expression, iterates standard input, and uses String#gsub (surprise!) 
to modify input. The pattern can also be configured to be used as-is, instead of as a regular expression - and of course,
the regular expression can be modified with a variety of switches.  
if a second argument is given, then that is the replacement string - if not, it defaults to an empty string.  
Example: `some-command | gsub '\r' # get rid of carriage returns!`

 + **htmlescape.rb**

"Escapes" html by mass-converting everything to HTML entities. Does it work? Eh, sort of.

 + **htmltext.rb**

Uses nokogiri extract visible text from a HTML document.

 + **nargs.rb**

An alternative to `xargs`, that, unlike `xargs`, does not split at any whitespace character, but instead, explicitly
***only*** at linefeeds. Includes pseudo-concurrency. Run 5000 commands at once! Your CPU will probably hate you for it, though.


 + **rbgrep.rb**

Born out of the inability of `grep` to handle grouped matches, rbgrep does just that.  
Obviously, performance-wise, rbgrep is far worse than grep.

 + **rbsed.rb**


 + **revlines.rb**


 + **runiq.rb**


 + **urldecode.rb**


 + **utf16fix.rb**



