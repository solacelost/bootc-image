#!/usr/bin/awk -f

function readfile(filename) {
    save_rs = RS
    RS = "^$"
    getline tmp < filename
    close(filename)
    RS = save_rs
    return tmp
}

match_found=0

/^#include/ {
  print "# START: " $2
  print readfile($2)
  print "# END: " $2
  match_found=1
}
match_found != 1 {
  print
}
