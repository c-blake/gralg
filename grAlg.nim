## Various algorithms on abstract directed graphs (digraphs, `dg`).  Beyond an
## integral type for node Ids, they only need a span `n` of such & iterators for
## `nodes(dg)` & `dests(dg, node)`.  Ids need not be dense on `0..<n`, but algos
## do allocate `n`-proportional space. TODO Maybe make routines be abstract Re:
## nodes containing needed metadata and ref/ptr node Ids?
#TODO Max Flow?  Other?
import std/[deques, algorithm, tables], gaPrioQ, cligen/sysUt; export tables

template reverse*(dg, nodes, dests, result): untyped =
  ## Add reverse arcs of `dg` to `result` (must have `mgetOrPut(Id, seq[Id])`).
  for x in nodes(dg):
    for y in dests(dg, x):
      result.mgetOrPut(y, @[]).add x

const gaMaxPath* {.intdefine.} = 10_000 # Diams even this big are very rare

template trace(pred, b, e, result) =
  var p = e                             # Build path from `pred[e]` links.
  while p != b and result.len < gaMaxPath:
    result.add p; p = pred[p]
  result.add b
  result.reverse

template shortestPathBFS*[I](dg; n: int; b,e: I; dests, did, pred, q): untyped =
  ## Breadth First Search For Shortest b -> e path; User provided mem buffers.
  var result: seq[I]                    # Initially all nodes have did[i]=false
  did.setLen n; zeroMem did[0].addr, n*did[0].sizeof
  pred.setLen n                         # Predecessors in first found path
  clear q; addLast q, b                 # Initialize q with just `b`.
  did[b]   = true                       # Mark first node done
  var done = false                      # Loop is unfinished
  while not done and q.len > 0:         # Standard BFS algorithm
    let x = popFirst q                  # Need FIFO order to get SHORTEST path
    for y in dests(dg, x):              #..Other orders halt @achievable paths.
      if not did[y]:
        did[y] = true
        pred[y] = x
        if y == e:                      # FOUND: trace reverse path & return
          trace pred, b, e, result
          done = true; break            # Could be `return` in a `proc`.
        else:
          addLast q, y
  result

template shortestPathBFS*[I](dg; n: int; b,e: I; dests): untyped =
  ## Breadth First Search For Shortest b -> e path; Uses new mem buffers.
  var did  = newSeqNoInit[bool](n)   # zeroed in leaf `shortestPathBFS`
  var pred = newSeqNoInit[I](n)
  var q    = initDeque[I](32)               # Nodes to check
  shortestPathBFS(dg, n, b, e, dests, did, pred, q)

template shortestPathPFS*[I](dg; C:type; n: int; b,e: I; nodes, dests): untyped=
  ## Dijkstra Min Cost Path Algorithm for b -> e; Unlike most other algos here,
  ## `dests` must be compatible with `for (dest, cost: C) in dests(dg, n): ..`.
  ## As with all Dijkstra, length/costs must be > 0 (but can be `float`).
  var result: seq[I]
  var cost = newSeq[C](n)               # This uses about 12*n space
  var pred = newSeqNoInit[I](n)         # Dijkstra Min Cost Path
  var idx  = newSeq[I](n)               # map[x] == heap index
  if true:                              # Scope for `proc`
    proc iSet(k: I, i: int) = idx[k.int] = I(i + 1) # 0 encodes MISSING
    var q: PrioQ[C, I]                  # Another 8*n space
    for i in nodes(dg):
      cost[i] = (if i == b: C(0) else: C.high)
      idx[i] = i + 1
      push q, cost[i], i, iSet
    while q.len > 0:
      let (xC, x) = q.pop(iSet)
      idx[x] = 0                        # Mark completed early to not re-do
      if xC != C.high:                  # reachable
        for (y, yC) in dests(dg, x):
          if idx[y] != 0:               # shortest remains undetermined
            let alt = cost[x] + yC
            if alt < cost[y]:
              cost[y] = alt
              pred[y] = x
              edit q, alt, idx[y] - 1, iSet
    trace pred, b, e, result            # trace path into result
  result

proc udcRoot*(up: var seq[int], x: int): int {.inline.} =
  result = x                            # Find root defined by parent == self
  while up[result] != result:
    result = up[result]
  var x = x                             # Compress path afterwards
  while up[x] != result:                #..by doing up[all x in path] <- result
    let up0 = up[x]; up[x] = result; x = up0

proc udcJoin(up, sz: var seq[int]; x, y: int) {.inline.} =
  let x = udcRoot(up, x)                # Join/union by size
  let y = udcRoot(up, y)
  if y != x:                            # x & y are not already joined
    if sz[x] < sz[y]:                   # Attach smaller tree..
      up[x] = y                         #..to root of larger
      sz[y] += sz[x]                    # and update size of larger
    else:                               # Mirror case of above
      up[y] = x
      sz[x] += sz[y]

template unDirComponIdSz*(dg; n: int; nodes, dests): untyped =
  ## Evals to an `up` componId array for each node Id in digraph `dg` treated as
  ## a reciprocated/undirected graph.
  var up = newSeq[int](n)               # nodeId -> parent id
  var sz = newSeq[int](n)               # nodeId -> sz
  for x in nodes(dg):                   # Initialize:
    up[x] = x; sz[x] = 1                #   parents all self & sizes all 1
  for x in nodes(dg):                   # Incorp edges via union-find/join-root
    for y in dests(dg, x): udcJoin up, sz, x, y
  (up, sz)                              # Now udcRoot(up, x) == componentId

template unDirCompons*(dg; n: int; nodes, dests): untyped =
  ## Evals to a `Table[cId, seq[nodeId]]` of connected components
  var (up, sz) = unDirComponIdSz(dg, n, nodes, dests)
  var t = initTable[int, seq[int]](n)   # Compon id => nodeId list
  for x in nodes(dg):                   # Add nodeIds to cId keys
    t.mgetOrPut(udcRoot(up, int(x)), newSeqOfCap[int](sz[x])).add x
  t

template unDirComponSizes*(dg; n: int; nodes, dests): untyped =
  ## Evals to a `CountTable[int]` of component sizes.
  var (up, _) = unDirComponIdSz(dg, n, nodes, dests)
  var t: CountTable[int]
  for x in nodes(dg): t.inc udcRoot(up, int(x))
  t

template transClosure*[I](dg; n: int; b: I; nodes, dests): untyped =
  ## Evals to a `seq[I]` containing the transitive closure of `b` on `dg`.
  var did = newSeq[bool](n)     # Could save space with `result: HashSet[I]` or
  var result: seq[I]            #..just `seq[T].contains` for really small TCs.
  if true:                      # scope for `proc`
    proc visit(x: I) =          # Depth First Search (DFS)
      result.add x; did[x] = true
      for y in dests(dg, x):
        if not did[y]: visit(y)
    visit(b)
  result

template topoSort*[I](dg; n: int; nodes, dests): untyped =
  ## Eval to a topological sort of the graph, or `len==0 seq` if cyclic.
  var did = newSeq[bool](n)     # Could save space with `result: HashSet[I]` or
  var result: seq[I]            #..just `seq[T].contains` for really small TCs.
  if true:                      # scope for `procs`
    proc visit(x: I) =          # Depth First Search (DFS)
      did[x] = true             # Mark current node as visited.
      for y in dests(dg, x):    # Recurse to all kids of this node
        if not did[y]: visit(y)
      result.add x              # Add node to stack storing reversed result
    for b in nodes(dg):
      if not did[b]: visit(b)
    result.reverse
  result

template isCyclic*[I](dg; n: int; nodes, dests; tsort: seq[I]): untyped =
  ## Eval to true if graph w/pre-computed topoSort `tsort` has any cycles.
  var ix = newSeqNoInit[I](n)   # Position of node in topological sort
  var result = false
  for j in 0 ..< tsort.len: ix[tsort[j].int] = I(j)
  block both:
    for x in nodes(dg):
      for y in dests(dg, x):
        if ix[x] > ix[y]: result = true; break both
  result
