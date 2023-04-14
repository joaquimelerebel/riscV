# LaTeXmk configuration file

# Usage example
# latexmk file.tex

# Main command line options
# -pdf : generate pdf using pdflatex
# -pv  : run file previewer
# -pvc : run file previewer and continually recompile on change
# -C   : clean up by removing all regeneratable files

# Generate pdf using pdflatex (-pdf)
$pdf_mode = 1;

# Define command to compile with pdfsync support and nonstopmode
$pdflatex = 'lualatex --shell-escape';

# Use default pdf viewer (Skim)
$pdf_previewer = 'open';

# Also remove pdfsync files on clean
$clean_ext = 'pdfsync synctex.gz';

$ENV{'TEXINPUTS'}='../../../rmrf-latex/:' . $ENV{'TEXINPUTS'};