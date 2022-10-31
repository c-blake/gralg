when not declared(assert): import std/assertions
import grAlg

let g = [ @[(1,10), (3,5)], @[(3,15)], @[(3,4), (0,6)], @[]]

iterator nods(dg: auto): int = (for i in 0..<dg.len: yield i)

iterator kids[R,A,B](dg: array[R,seq[(A,B)]], x: int): (A,B) =
  for e in dg[x]: yield e

let mst = minSpanTree(g, g.len, nods, kids)

assert mst == @[(4, 2, 3), (5, 0, 3), (10, 0, 1)]
