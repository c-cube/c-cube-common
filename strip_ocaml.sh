#!/bin/sh

# thanks to Kakadu for the tip!

#find $(opam var bin) -iname '*.byte' -delete \;
find $(opam var bin) -iname 'ocamlformat.parser_reconver.test*' -delete
find $(opam var lib) \( -iname '*.cmt' -o -iname '*.cmti' \) -delete
find $(opam var prefix) -iname '*.exe' -exec strip {} \;
