# Package
version     = "0.5.2"
author      = "Charles Blake"
description = "Classical Graph Algos in Nim"
license     = "MIT/ISC"

# Dependencies
requires "nim >= 1.2.0", "cligen >= 1.9.1"

installFiles = @[ "gaPrioQ.nim" ]
bin          = @[ "util/conncomp" ]
