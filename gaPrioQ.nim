## Dijkstra's Shortest Path edits priority.  API calls pass an `iSet` to update
## a K->index map.  Caller map updates on mutate allows their own GONE encoding.
type
  PrioQ*[P,K] = object              ## A priority queue that can edit priorities
    data*: seq[(P, K)]              ## [0]=root; [--i//2]=par(i); [2*i+1|2]=kids
  ISet*[K] = proc(key: K, i: int)   ## Type of proc used to maintain K->i map
proc initPrioQ*[P,K](): PrioQ[P,K]=discard ## Make an empty; Just decl also ok.
proc len*[P,K](q: PrioQ[P,K]): int{.inline.}= q.data.len ## Num elements in `q`.

proc lift[P,K](q: var PrioQ[P,K]; i0, i: int, iSet: ISet[K]) =
  var j  = i                    # Restore heapness; Assumes `q` is a heap at all
  let it = q.data[j]            #..`j >= i0`, except for maybe out-of-order `i`.
  while j > i0:                 # Follow path to root, moving parents
    let parIdx = (j - 1) shr 1  #..down until finding spot for `it`.
    let parVal = q.data[parIdx]
    if it[0] < parVal[0]:
      q.data[j] = parVal; iSet parVal[1], j
      j = parIdx
    else: break
  q.data[j] = it; iSet it[1], j

proc buryDeep[P,K](q: var PrioQ[P,K], i: int, iSet: ISet[K]) =
  let i0 = i
  var i  = i
  let it = q.data[i]
  while (var k1 = 2*i + 1; k1 < q.len):         # While not at a leaf node..
    let k2 = k1 + 1                             #   k1,k2 = left,right kid
    if k2 < q.len and not (q.data[k1][0] < q.data[k2][0]):
      k1 = k2                                   #   make k1 = smaller kid
    q.data[i] = q.data[k1]; iSet q.data[i][1],i #   Lift k1
    i = k1
  q.data[i] = it; iSet q.data[i][1], i  # [i] leaf is now empty. Put `it` there
  q.lift i0, i, iSet                    # Lift to final spot by burying parents

proc push*[P,K](q: var PrioQ[P,K], prio: P, key: sink K, iSet: ISet[K]) =
  ## Push `(prio,key)` onto `q`; Caller pre-adds `iSet(key, q.len)` to the map.
  q.data.add (prio, key)                # incs q.len by 1, reversed below
  q.lift 0, q.len - 1, iSet

proc pop*[P,K](q: var PrioQ[P,K], iSet: ISet[K]): (P, K) =
  ## Pop & return smallest `(P,K)`; Caller post-removes from map used by `iSet`.
  let last = q.data.pop
  if q.len == 0: result = last
  else:
    result = q.data[0]
    q.data[0] = last
    q.buryDeep 0, iSet

proc bury[P,K](q: var PrioQ[P,K], i: int, iSet: ISet[K]) =
  var i  = i
  let it = q.data[i]
  while (var k1 = 2*i + 1; k1 < q.len):         # While not at a leaf node..
    let k2 = k1 + 1                             #   k1,k2 = left,right kid
    if k2 < q.len and not (q.data[k1][0] < q.data[k2][0]):
      k1 = k2                                   #   make k1 = smaller kid
    if not (q.data[k1][0] < it):
      break
    q.data[i] = q.data[k1]; iSet q.data[i][1], i
    i = k1
    k1 = 2*k1 + 1
  q.data[i] = it; iSet q.data[i][1], i

proc replace*[P,K](q: var PrioQ[P,K], prio: P, key: sink K, iSet:ISet[K]):(P,K)=
  ## Pop & return current smallest value and push the new (prio, key) pair.
  result = q.data[0]
  q.data[0] = (prio, key)
  q.bury 0, iSet

proc pushpop*[P,K](q: var PrioQ[P,K], prio: P, key: sink K, iSet:ISet[K]):(P,K)=
  ## Fast version of a `push` followed by a `pop`.
  result = (prio, key)
  if q.len > 0 and q.data[0] < result:
    swap result, q.data[0]
    q.bury 0, iSet

proc edit*[P,K](q: var PrioQ[P,K], prio: P, i: int, iSet: ISet[K]) =
  ## Alter priority for key at index `i`;  Caller does nothing with its map.
  q.data[i][0] = prio           #XXX validate that prio < old
  q.lift 0, i, iSet             #XXX and/or do both lift & bury

when isMainModule:
  import std/strformat, cligen/osUt
  proc chk[P,K](q: PrioQ[P,K]) =
   let n = q.data.len
   for i in 0 ..< n div 2:
     if 2*i+1<n and q.data[2*i+1][0] < q.data[i][0]: erru &"[2*{i}+1] < [{i}]\n"
     if 2*i+2<n and q.data[2*i+2][0] < q.data[i][0]: erru &"[2*{i}+2] < [{i}]\n"
  var idx = newSeq[int](8)
  proc iSet(k: int8, i: int) = idx[k.int] = i
  var q: PrioQ[float, int8]
  for (w,k) in [(4.0,6i8), (1.0,4i8), (9.0,5i8), (8.0,3i8),
                (6.0,1i8), (7.0,0i8), (5.0,7i8), (3.0,2i8)]: q.push w, k, iSet
  q.chk
  q.edit 0.5, idx[6i8.int], iSet
  q.chk
  while q.len > 0: echo q.pop(iSet)
