import grAlg

let g = [ @[1,2], @[2], @[0,3], @[3]]

iterator nods(dg: auto): int = (for i in 0..<dg.len: yield i)

iterator kids[R,T](dg: array[R,seq[T]], x: int): T = (for e in dg[x]: yield e)

assert g.transClosure(4, 1, nods, kids) == @[1, 2, 0, 3]
