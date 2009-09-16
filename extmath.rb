#!/usr/bin/env ruby
# 
# Extract all math symbols in a TeX file and create
# PDF for them, one by one.
#
# Inspired by OGEquasion: http://macinscience.org/?p=12
#
# by shigeya, September 2009
#

require 'digest/md5'

class MathPDF

  def initialize
    @syms = Hash.new {|h,k| h[k] = 0 }
    @resolution = 600
    @code = "EUC-JP"
  end

  def calc_hash(v)
    Digest::MD5.hexdigest(v)
  end

  def scan(file)
    open(file, "r:#{@code}:UTF-8") do |f|
      f.each do |l|
        unless l =~  /^\s*\%/
          while l.sub!(/\$Id:[^$]*\$/, "")
          end
          while l.sub!(/\$\$([^$]*)\$\$/, "")
            @syms[$1] = calc_hash($1)
          end
          while l.sub!(/\$([^$]*)\$/, "")
            @syms[$1] = calc_hash($1)
          end
        end
      end
    end
  end


  def generate_tex(v)
    open("#{@syms[v]}.tex", "w") do |w|
      w.puts <<EOF
\\documentclass{article}
\\usepackage{amsmath,amssymb}
\\pagestyle{empty}
\\begin{document}
% If you want to change the size of equation, edit next line.
{\\Huge
\\begin{eqnarray*}
#{v}
\\end{eqnarray*}
}
\\end{document}
}
EOF
    end
  end

  def generate_pdf(v)
    base = @syms[v]
    unless FileTest.exist?("#{base}.tex")
      generate_tex(v)
    end
    unless FileTest.exist?("#{base}.pdf")
      system("latex #{base}")
      system("dvips -E -f -X #{@resolution} -Y #{@resolution} #{base}.dvi > #{base}.ps")
      system("epstopdf #{base}.ps")
      system("/bin/rm #{base}.tex #{base}.aux #{base}.dvi #{base}.ps #{base}.log")
    end
  end
  
 
  def post_process
    @syms.keys.sort.each {|k| generate_pdf(k)}
  end
end

#
# main
#

if __FILE__ == $0
  math_pdf = MathPDF.new
  ARGV.each {|f| math_pdf.scan(f) }
  Dir.chdir("Drawings/Math")
  math_pdf.post_process
end
