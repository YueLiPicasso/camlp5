#!/bin/sh -e
if test "$(basename "$(dirname $OTOP)")" != "ocaml_stuff"; then
    COMM="$OTOP/boot/ocamlrun$EXE $OTOP/ocamlc -I $OTOP/stdlib"
else
    COMM=ocamlc$OPT
fi
echo $COMM $*
$COMM $*
