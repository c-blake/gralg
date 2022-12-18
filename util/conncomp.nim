import tables, sets, grAlg, cligen
when not declared(stdin): import std/syncio

proc id*[T](ids: var Table[T,SomeInteger], obs: var seq[T], ob: T): SomeInteger=
  ## Get dense integer id for maybe-done `ob`, updating `ids` & `obs`. `tables`?
  try:
    result = ids[ob]                    # Already known => done
  except KeyError:                      # Put into ob->id & id->ob
    result = obs.len
    ids[ob] = result
    obs.add ob

proc conncomp(idelim='\t', odelim="\t", n=1024, e=4096) =
  ## Print connected components of the (undirected) graph on stdin as lines of
  ## `idelim` edges.  Output is lines of `odelim`-delimited token clusters.
  var ids   = initTable[string, int](n)         # token -> vertex int id number
  var toks  = newSeqOfCap[string](n)            # vertex int id -> token
  var edges = initTable[int, HashSet[int]](e)   # digraph as id -> destIds
  let empty = initHashSet[int](e div n)

  for ln in lines(stdin):                       # Parse input, assign node ids,
    let cs = ln.split(idelim)                   #..and load up `edges`.
    edges.mgetOrPut(ids.id(toks, cs[0]), empty).incl(
                    ids.id(toks, cs[1]))

  iterator nodes(edges: Table[int, HashSet[int]]): int =
    for i in 0 ..< toks.len: yield i

  iterator dests(edges: Table[int, HashSet[int]], x: int): int =
    for d in edges.getOrDefault(x, empty): yield d

  for c in edges.unDirCompons(toks.len + 1, nodes, dests).values:
    for i, e in c:
      stdout.write toks[e]
      if i < c.len - 1:
        stdout.write odelim
    stdout.write "\n"

dispatch conncomp, help={"idelim": "edge delimiter",
                         "odelim": "in-cluster delimiter",
                         "n"     : "guess at num of unique token nodes",
                         "e"     : "guess at num of edges"}
