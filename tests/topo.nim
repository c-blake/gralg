import grAlg

let g: seq[seq[int]] = @[ @[], @[], @[3], @[1], @[0, 1], @[2, 0] ]
let c: seq[seq[int]] = @[ @[1,2], @[2], @[0,3], @[] ]
iterator nods(dg: seq[seq[int]]): int = (for i in 0..<dg.len: yield i)
iterator kids(dg: seq[seq[int]], x: int): int = (for i in dg[x]: yield i)
let gts = topoSort[int](g, g.len, nods, kids)
assert gts == @[5, 4, 2, 3, 1, 0]
assert isCyclic(g, g.len, nods, kids, gts) == false
assert isCyclic(c, c.len, nods, kids, topoSort[int](c, c.len, nods, kids))
