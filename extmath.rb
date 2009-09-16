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
  
  def initialize(opts)
    @opts = opts
    @syms = Hash.new {|h,k| h[k] = 0 }
  end

  def calc_hash(v)
    Digest::MD5.hexdigest(v)
  end

  def scan(file)
    open(file, "r:#{@opts[:file_encoding]}:UTF-8") do |f|
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
    if @opts[:recreate] or FileTest.exist?("#{base}.pdf") == false
      unless FileTest.exist?("#{base}.tex")
        generate_tex(v)
      end
      system("#{@opts[:latex]} #{base}")
      system ("#{@opts[:dvips]} -E -f -X #{@opts[:resolution]} -Y #{@opts[:resolution]} #{base}.dvi > #{base}.ps")
      system("#{@opts[:epstopdf]} #{base}.ps")
      @opts[:unlink_list].each {|s| File.unlink(base+s) }
    end
  end
  
  def post_process
    @syms.keys.sort.each {|k| generate_pdf(k)}
  end

  def write_map
    if @opts[:create_map] != nil
      open(@opts[:create_map], "w:#{@opts[:file_encoding]}:UTF-8") do |f|
        a = [ ]
        @syms.keys.each {|k| a.push("#{@syms[k]}\t#{k}") }
        a.sort.each {|v| f.puts v}
      end
    end
  end

end

#
# main
#

if __FILE__ == $0
  require 'optparse'

  opts = {                      # default options
    :create_map => "symbol-map.txt",
    :recreate => false,
    :resolution => 600,
    :path => "./Temp",
    :retain_tex => false,
    :retain_eps => false,
    :file_encoding => "EUC-JP",
    :latex => "latex",
    :dvips => "dvips",
    :epstopdf => "epstopdf",
    :unlink_list => [".tex", ".aux", ".dvi", ".ps", ".log"]
  }

  ARGV.options do |o|
    o.banner = "ruby #{$0} [options] TeX-files..."
    o.separator "Options:"

    o.on("-F", "--force", "Force recreate all files") {|x| opts[:recreate] = true }
    o.on("-N", "--no-map", "Don't create math-index.map file") {|x| opts[:create_map] = false }
    o.on("-M MAP", "--map MAP", "create map file with name") {|x| opts[:create_map] = x }

    o.on("-r resolution", "--resolution r", "Output resolution (default:#{opts[:resolution]})") {|x| opts[:resolution] = x.to_i }

    o.on("-p path", "--path path", "Directory to generate PDFs (default: #{opts[:path]})") {|x| opts[:path] = x }

    o.on("-T", "--retain-tex", "Retain TeX output file") do |x|
      opts[:unlink_list].delete_if {|s| s == ".tex"}
    end

    o.on("-E", "--retain-ps", "Retain PS output file") do
      opts[:unlink_list].delete_if {|s| s == ".ps" }
    end

    o.on("-P", "--remove-pdf", "Remove PDF output file") do
      opts[:unlink_list].push(".pdf")
    end

    o.parse!

  end

  math_pdf = MathPDF.new(opts)
  ARGV.each {|f| math_pdf.scan(f) }

  Dir.chdir(opts[:path])
  math_pdf.post_process
  math_pdf.write_map
end
