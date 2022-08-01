This is a small collection of classical graph algorithms on digraphs in Nim.

The core abstractions representing a graph are some kind of not necessarily
dense integer-like address space, some nodes iterator on the graph and some
edges(graph, node) iterator on the kids of a node/destinations of arcs.

It also contains (also at the top level) `pq.nim` since the shortest path
algorithm made famous by Dijkstra needs a priority queue that can efficiently
edit entry priorities and `std/heapqueue` does not allow this.

https://github.com/c-blake/thes has demos/tests of most of these algorithms,
but a quick list is:
  * arc/edge reversal
  * topological sorting/testing for DAG/cyclicity
  * transitive closure
  * shortest path from beginning to end via BFS
  * shortest path from beginning to end via Dijkstra
  * components when viewed as an undirected graph

Should probably grow MST, Max Flow, and weak strong components algorithms.
