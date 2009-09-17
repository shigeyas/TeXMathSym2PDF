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
    @syms = Hash.new
  end

  def calc_hash(v)
    Digest::MD5.hexdigest(v)
  end

  def add(v)
    v.gsub!(/\n/, " ")
    v.gsub!(/\s+/, " ")
    @syms[v] = calc_hash(v)
  end

  def add_block(v)
    if @opts[:output_by_line]
      v.each {|e| add(e) }
    end
    if @opts[:output_by_box]
      add(v.join(" "))
    end
  end

  ############################################## eqnarray environment processor
  class LineProcessor
    def initialize(pdf, pat)
      @line = Array.new
      @pat = pat
      @pdf = pdf
    end

    def store
    end

    def process_line(l)
    end

    def process(l)
      if l =~ @pat
        store
        return nil
      end
      process_line(l)
      self
    end
  end

  class EQNArrayLine < LineProcessor
    def initialize(pdf)
      super(pdf, /\\end\{eqnarray\}/)
    end

    def process_line(l)
      l.sub!(/\s+\\label\{[^}]+\}\s+/,"") # remove any labels
      @line.push(l)
    end

    def store
      # outer is already eqnarray. drop them.
      @pdf.add_block(@line)
    end
  end

  ############################################## 

  def read_preamble
    @preamble = ""
    if @opts[:preamble] != nil and FileTest.exist?("#{@opts[:preamble]}")
      a = File.readlines(@opts[:preamble]) # XXX need care on encodings..
      @preamble = a.join
    end
  end


  def scan(file)
    open(file, "r#{@opts[:file_encoding]}") do |f|
      a = nil
      f.each do |l|
        unless l =~  /^\s*\%/
          if a != nil # if it's in eqn mode
            a = a.process(l)
          elsif l =~ /\\begin\{eqnarray\}/
            a = EQNArrayLine.new(self)
          else
            while l.sub!(/\$Id:[^$]*\$/, "")
            end

            while l.sub!(/\$\$([^$]*)\$\$/, "")
              add($1)
            end

            while l.sub!(/\$([^$]*)\$/, "")
              add($1)
            end
          end
        end
      end
    end
  end


  def generate_tex(v)
    open("#{@syms[v]}.tex", "w#{@opts[:file_encoding]}") do |w|
      w.puts <<EOF
\\documentclass{article}
\\usepackage{amsmath,amssymb}
\\pagestyle{empty}
#{@preamble}
\\begin{document}
% If you want to change the size of equation, edit next line.
{\\#{@opts[:size_param]}
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
    if @opts[:recreate] or ( (FileTest.exist?("#{base}.pdf") == false and @opts[:output_pdf] == true) or (FileTest.exist?("#{base}.ps") == false and @opts[:output_pdf] == false ) )
      unless FileTest.exist?("#{base}.tex")
        generate_tex(v)
      end
      system("#{@opts[:latex]} #{base}")
      system("#{@opts[:dvips]} -E -f -X #{@opts[:resolution]} -Y #{@opts[:resolution]} #{base}.dvi > #{base}.ps")
      system("#{@opts[:epstopdf]} #{base}.ps") if @opts[:output_pdf]
      @opts[:unlink_list].each {|s| File.unlink(base+s) }
    end
  end
  
  def post_process
    @syms.keys.sort.each {|k| generate_pdf(k)}
  end

  def write_map
    if @opts[:create_map] != nil
      open(@opts[:create_map], "w#{@opts[:file_encoding]}") do |f|
        a = Array.new
        @syms.keys.each {|k| kk = k.gsub(/\n/, " "); a.push("#{@syms[k]}\t#{kk}") }
        a.sort.each {|v| f.puts v}
      end
    end
  end

  def output_prep
    Dir.chdir(@opts[:path])
    read_preamble
  end
  
  def scan_files(av)
    av.each {|f| scan(f) }
  end
  
  def run(av)
    scan_files(av)
    output_prep
    post_process
    write_map
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
    :preamble => "math-preamble.tex",
    :file_encoding => ":BINARY",
    :latex => "latex",
    :dvips => "dvips",
    :epstopdf => "epstopdf",
    :unlink_list => [".tex", ".aux", ".dvi", ".ps", ".log"],
    :output_pdf => true,
    :size_param => "Huge",
    :output_by_box => true,
    :output_by_line => false
  }

  ARGV.options do |o|
    o.banner = "ruby #{$0} [options] TeX-files..."
    o.separator "Options:"

    o.on("-F", "--force", "Force recreate all files") {|x| opts[:recreate] = true }
    o.on("-N", "--no-map", "Don't create math-index.map file") {|x| opts[:create_map] = false }
    o.on("-m MAP", "--map MAP", "create map file with name (Default: #{opts[:create_map]})") {|x| opts[:create_map] = x }
    o.on("-s SIZE", "--size SIZE", "specify size parameter (default:#{opts[:size_param]})") {|x| opts[:size_param] = x }

    o.on("-r RESOLUTION", "--resolution RESOLUTION", "Output resolution (default:#{opts[:resolution]})") {|x| opts[:resolution] = x.to_i }

    o.on("-p PATH", "--path PATH", "Directory to generate PDFs (default: #{opts[:path]})") {|x| opts[:path] = x }

    o.on("-i PREAMBLE", "--include PREAMBLE", "Includ this file in TeX preamble if exists (default: #{opts[:preamble]})") {|x| opts[:preamble] = x }

    o.on("-T", "--retain-tex", "Retain TeX output file") do |x|
      opts[:unlink_list].delete_if {|s| s == ".tex"}
    end

    o.on("-E", "--retain-ps", "Retain PS output file") do
      opts[:unlink_list].delete_if {|s| s == ".ps" }
    end

    o.on("-P", "--no-pdf", "don't output PDF file") do
      opts[:output_pdf] = false
    end

    o.on("-J", "--japanese", "Configure for Japanese environment") do
      opts[:latex] = "platex"
    end

    o.on("-L", "--by-line", "Output only by line in eqnarray") {|x| opts[:output_by_line] = true; opts[:output_by_box] = false }
    o.on("-B", "--by-box", "Output only by box in eqnarray") {|x| opts[:output_by_line] = false; opts[:output_by_box] = true }
    o.on("-A", "--by-box-and-line", "Output both box and line-by-line in eqnarray") {|x| opts[:output_by_line] = true; opts[:output_by_box] = true }

    o.parse!

  end

  math_pdf = MathPDF.new(opts)
  math_pdf.run(ARGV)
end
