## Given m-row-by-n-col A, m-vec b & n-vec c, solve LP: max c.x | A.x<=b & dual
## min b.y | yA>=c; x,y>=0.  Assumes b>=0 (so x=0 is a basic feasible solution).
## Makes (m+1)*(n+m+1) simplex tableau w/RHS in column m+n, objective in row m &
## slack vars in cols m through m+n-1.  Use Bland's Rule for coming & going vars
## & minRatio for colPiv.  Impl is slow for big input & frail from FP rounding.
import std/[formatFloat, syncio]
template sum0*(i, n, ex: untyped): untyped = (block:   # from fitl/basicLA
  var i{.inject.}: type(n); var tot: type(ex); (for i in 0..<n: tot += ex); tot)
proc dot*[F](x,y:openArray[F]):F=(if x.len!=y.len:0 else:sum0(i,x.len,x[i]*y[i]))
type F = float; const eps = 1e-11 # `F`-precision^~2/3

# Core algo is here to end of initDPlex() maker
type DPlex* = object    ## State for running D)ense-D)antzig SimPlex Algorithm
  a*: seq[F]            ## Tableau
  m*, n*, N*: int       ## Number of constraints, original variables, tab span
  bv*: seq[int]         ## [i]=basic var for row i only needed for prim()

proc blandRule(s: DPlex): int = # Lowest ix of a non-basic column with >0 cost
  result = -1; for j in 0 ..< s.m + s.n: (if s.a[s.m*s.N + j] > 0: return j)

proc minRatioRule(s: DPlex, q: int): int =   # Find row p w/minRatioRule (-1 if
  result = -1; let N=s.N;let m=s.m;let n=s.n # none; Smallest such ix if tied).
  for i in 0 ..< s.m:
    if s.a[i*N + q] > eps:
      if   result == -1: result = i
      elif s.a[i*N + m+n]*s.a[result*N + q] < s.a[result*N + m+n]*s.a[i*N + q]:
        result = i

proc pivot(s: var DPlex; p,q: int) = # Pivot on [p,q] w/Gauss-Jordan elimination
  let N = s.N; for i in 0 .. s.m:
    if i != p:                  # Everything but row p & column q
      for j in 0 .. s.m+s.n:
        if j != q: s.a[i*N + j] -= s.a[p*N + j]*(s.a[i*N + q]/s.a[p*N + q])
  for i in 0 .. s.m    : (if i != p: s.a[i*N + q] = 0)             # Zero Col q
  for j in 0 .. s.m+s.n: (if j != q: s.a[p*N + j] /= s.a[p*N + q]) # Scale Row p
  s.a[p*N + q] = 1

proc solve(s: var DPlex) =      # Do Simplex Algo starting from initial BFS
  while (let q = s.blandRule; q != -1): # Find coming column q & maybe stop
    let p = s.minRatioRule(q) #[; echo "(p,q): ",p," ",q ]#  # Find going row p
    if p == -1: raise newException(ValueError, "Unbounded Linear Program")
    s.pivot(p, q); s.bv[p] = q  # Pivot & Update basis var; Q: Iteration Limit?

proc initDPlex*(c, A, b: openArray[F]): DPlex = ## Solve Lin.Prog A,b,c -> DPlex
  let m = b.len; let n = c.len; let N = n+m+1; result.m=m;result.n=n;result.N=N
  for b in b: (if b < 0: raise newException(ValueError, "RHS must be >= 0"))
  result.a.setLen (m + 1)*(n + m + 1)               # Allocate zeroed memory
  for i in 0..<m:
    for j in 0..<n: result.a[i*N + j] = A[i*n + j]  # copyMem
    result.a[i*N + n+i] = 1
    result.a[i*N + m+n] = b[i]
  for j in 0..<n: result.a[m*N + j] = c[j]          # copyMem
  result.bv.setLen m; for i in 0..<m: result.bv[i] = n + i
  result.solve()                # Caller can check failed if desired

# Extract & check solutions from a `DPlex`
proc optimVal*(s: DPlex): F = -s.a[s.m*s.N + s.m+s.n] ## Optimum for the LP

proc prim*(s: DPlex): seq[F] =  ## Optimal primal solution x
  result.setLen s.n
  for i in 0..<s.m: (if s.bv[i] < s.n: result[s.bv[i]] = s.a[i*s.N + s.m+s.n])

proc dual*(s: DPlex): seq[F] =  ## Optimal dual solution y
  result.setLen s.m; for i in 0..<s.m: result[i] = -s.a[s.m*s.N + s.n+i]

proc primInfeas(s: DPlex; A, b: openArray[F], f=stderr): bool =
  let x = s.prim                # Check that x >= 0 and A.x <= b
  for j, x in x: (if x < -eps: (f.write("x[",j,"] ",x," neg\n"); return true))
  for i, b in b: (if (let t = sum0(j, s.n, A[i*s.n + j]*x[j]); t > b + eps):
    f.write "p-infeas: b[",i,"] ",b," Axi ",t,"\n"; return true)

proc dualInfeas(s: DPlex; A, c: openArray[F], f=stderr): bool =
  let y = s.dual                # Check that y >= 0 and y.A' >= c
  for i, y in y: (if y < -eps: (f.write("y[",i,"] ",y," neg"); return true))
  for j, c in c: (if (let t = sum0(i, s.m, y[i]*A[i*s.n + j]); t < c - eps):
    f.write "d-infeas: c[",j,"] ",c," yAj ",t,"\n"; return true)

proc nonOptimal(s: DPlex; b, c: openArray[F], f=stderr): bool = # optVal=cx=yb
  let v = s.optimVal; let cx = dot(c, s.prim); let yb = dot(s.dual, b)
  if abs(v - cx) > eps or abs(v - yb) > eps:
    f.write "v ",v," cx ",cx," yb ",yb,"\n"; return true

proc failed*(s: DPlex; c, A, b: openArray[F], f=stderr): bool =
  ## Test if optimization failed and, if so, log why to File `f`.
  s.primInfeas(A, b) or s.dualInfeas(A, c) or s.nonOptimal(b, c)

when isMainModule: # Could very profitably grow a sparse system variant
  import std/assertions                     # Unit tests
  proc test(label: string; c, A, b: openArray[F]) =
    try: (echo("TEST ",label); let s=initDPlex(c,A,b);assert not s.failed(c,A,b)
      echo "optimVal = ",s.optimVal();
      for i, x in s.prim: echo "x[",i,"] = ",x
      for j, y in s.dual: echo "y[",j,"] = ",y)
    except Exception as e: echo e.msg
  test "1", [ 1.0, 1, 1 ], [ -1.0,  1,  0,  # Test cases from (verbose!) _Algos
                                1,  4,  0,  #..in Java_ by Sedgewick & Wayne.
                                2,  1,  0,
                                3, -4,  0,
                                0,  0,  1 ], [ 5.0, 45, 27, 24, 4 ]
  test "2", [ 13.0, 23 ], [ 5.0, 15,                # x0=12 x1=28 opt=800
                              4,  4,
                             35, 20 ], [ 480.0, 160, 1190 ]
  test "U", [ 2.0, 3, -1, -12 ], [ -2.0, -9,  1,  9,      # Unbounded
                                      1,  1, -1, -2 ], [ 3.0, 2 ]
  test "C", [ 10.0, -57, -9, -24 ], [ 0.5, -5.5, -2.5, 9, # Cycles w/o Bland
                                      0.5, -1.5, -0.5, 1,
                                      1.0,  0.0,  0.0, 0 ], [ 0.0, 0, 1 ]
  import std/[os, strutils, random]; when defined(release): randomize()
  let m = if paramCount() >= 1: parseInt(paramStr(1)) else: 3
  let n = if paramCount() >= 2: parseInt(paramStr(2)) else: 5
  var A = newSeq[F](m*n); var b = newSeq[F](m); var c = newSeq[F](n)
  for i in 0..<m: (for j in 0..<n: A[i*n + j] = rand(99).F)
  for i in 0..<m: b[i] = rand(999).F
  for j in 0..<n: c[j] = rand(999).F
  test "R", c, A, b
