# Package
version     = "0.5.1"
author      = "Charles Blake"
description = "Classical Graph Algos in Nim"
license     = "MIT/ISC"

# Dependencies
requires "nim >= 1.2.0", "cligen >= 1.7.8"

installFiles = @[ "gaPrioQ.nim" ]
bin          = @[ "util/conncomp" ]
