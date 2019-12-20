#!/usr/bin/ruby

def toutf(str, &b)
  
end

function convertCharStr2Rust(str, parameters)
{
    // Converts a string of characters to Rust escapes
    // str: sequence of Unicode characters
    // parameters: a semicolon separated string showing ids for checkboxes that are turned on
    var highsurrogate = 0;
    var suppCP;
    var pad;
    var n = 0;
    var pars = parameters.split(';');
    var outputString = '';
    for (var i = 0; i < str.length; i++)
    {
        var cc = str.charCodeAt(i);
        if (cc < 0 || cc > 0xFFFF)
        {
            outputString += '!Error in convertCharStr2UTF16: unexpected charCodeAt result, cc=' + cc + '!';
        }
        if (highsurrogate != 0)
        { // this is a supp char, and cc contains the low surrogate
            if (0xDC00 <= cc && cc <= 0xDFFF)
            {
                suppCP = 0x10000 + ((highsurrogate - 0xD800) << 10) + (cc - 0xDC00);
                pad = suppCP.toString(16).toUpperCase();
                outputString += '\\u{' + pad + '}';
                highsurrogate = 0;
                continue;
            }
            else
            {
                outputString += 'Error in convertCharStr2UTF16: low surrogate expected, cc=' + cc + '!';
                highsurrogate = 0;
            }
        }
        // start of supplementary character
        if (0xD800 <= cc && cc <= 0xDBFF)
        {
            highsurrogate = cc;
        }
        else
        { // this is a BMP character
            //outputString += dec2hex(cc) + ' ';
            switch (cc)
            {
                case 0:
                    outputString += '\\0';
                    break;
                case 8:
                    outputString += '\\b';
                    break;
                case 9:
                    if (parameters.match(/noCR/))
                    {
                        outputString += '\\t';
                    }
                    else
                    {
                        outputString += '\t'
                    };
                    break;
                case 10:
                    if (parameters.match(/noCR/))
                    {
                        outputString += '\\n';
                    }
                    else
                    {
                        outputString += '\n'
                    };
                    break;
                case 13:
                    if (parameters.match(/noCR/))
                    {
                        outputString += '\\r';
                    }
                    else
                    {
                        outputString += '\r'
                    };
                    break;
                case 11:
                    outputString += '\\v';
                    break;
                case 12:
                    outputString += '\\f';
                    break;
                case 34:
                    if (parameters.match(/noCR/))
                    {
                        outputString += '\\\"';
                    }
                    else
                    {
                        outputString += '"'
                    };
                    break;
                case 39:
                    if (parameters.match(/noCR/))
                    {
                        outputString += "\\\'";
                    }
                    else
                    {
                        outputString += '\''
                    };
                    break;
                case 92:
                    outputString += '\\\\';
                    break;
                default:
                    if (cc > 0x00 && cc < 0x20)
                    {
                        outputString += '\\x' + cc.toString(16).toUpperCase()
                    }
                    else if (cc > 0x7E && cc < 0xA0)
                    {
                        outputString += '\\x' + cc.toString(16).toUpperCase()
                    }
                    else if (cc > 0x1f && cc < 0x7F)
                    {
                        outputString += String.fromCharCode(cc)
                    }
                    else
                    {
                        pad = cc.toString(16).toUpperCase();
                        //while (pad.length < 4) { pad = '0'+pad; }
                        outputString += '\\u{' + pad + '}'
                    }
            }
        }
    }
    return outputString;
}
