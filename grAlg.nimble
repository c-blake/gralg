# Package
version     = "0.4.4"
author      = "Charles Blake"
description = "Classical Graph Algos in Nim"
license     = "MIT/ISC"

# Dependencies
requires "nim >= 1.2.0", "cligen >= 1.6.18"

installFiles = @[ "gaPrioQ.nim" ]
bin          = @[ "util/conncomp" ]
