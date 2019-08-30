#!/bin/bash -x

jupyter-nbconvert  --to markdown "$1" --config jekyll_config.py --template=jekyll.tpl --Application.log_level='DEBUG'


outputname=$(basename "$1" .ipynb)
outputpath=${1%.ipynb}

postname=$(date +"%Y-%m-%d-")$(echo $outputname | tr " " -)
mv "$outputpath.md" "../../_posts/$postname.md"

mv  "$outputname"_files ../../posts_assets/
