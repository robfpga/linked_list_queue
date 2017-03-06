# Linked List Queue

[![Build Status](https://travis-ci.org/stephenry/linked_list_queue.svg?branch=master)](https://travis-ci.org/stephenry/linked_list_queue)

## Introduction

FIFO buffers (also known as Queues) are a mainstay of logic design. Standard
Queue designs allocate state from a statically sized pool of memory. Once such a
pool has been exhausted, the FIFO is FULL and becomes blocked to upstream
clients.

Often, it becomes necessary to maintain multiple queues for differing
contexts. In the case whether such state may not be retained in a single queue
(with appropriate state annotations), it becomes necessary to maintain N
individual Queues for each of the N contexts in the system.

The requirement to maintain N seperate queues becomes inefficient when the
latency across each context becomes high. In this case, each Queue must be sized
towards the worst case condition each though this condition is pathelogical and
non-illustrative of normative conditions.

A secondary solution is to maintain N queues a individual Listed Lists data
structures from a single state table. In this case, the size of each Queue can
be allocated on demand to each context and the overall area of the solution
reduced.

## System Requirements
* cmake >= 3.2
* systemc >= 2.3.1
* verilator >= 3.9
* clang >= 3.9

## Build Steps
~~~~
git clone https://github.com/stephenry/linked_list_queue
cd linked_list_queue
git submodule update --init --recursive
cmake ../
make
~~~

## Parameterizations

* W the number of state bits remained by each Queue entry.

* CTXT The number of independent contexts maintain by the Queue.

* M the number of entries in the combined link table data structure.

## Memory Requirements

The following memories are required by the design:

* A dual-ported synchronous RAM of 1 + 2LOG2(M) bits x CTXT words to retain
  context state.

* A single ported synchronus RAM of LOG2(M) bits x M words to maintain link
  state.

* A single ported synchronous RAM of W b x M words.


## Micro-architecture

The presented solution is fully pipelined and capable of consuming one command
per cycle.

By consequence of the nature of Linked List data structures, it is not possible
to execute back-to-back pop operations to the same context. This limiation
arises from the fact that the lookup of any secondary lookup may only precede
once the initial lookup has completed. To accomplish this, forwarding logic is
necessary at the output of the link-state RAM to its input. This cannot be
realized while maintaining a competitive clock frequency.

There are no limitations PUSH operations nor operations to varying contexts.

## Error handling

Push to a FULL state and Pops from an EMPTY state and internally killed and do
not modify state. Completions on the result interface from such commands are
specifically annotated. External logic must consider the possible of such
failure scenarios as there is implicitly some latency between when a POP is
issued and the time EMPTY state is updated (upon commit). In constrast, FULL
state is updated on instruction ISSUE and is therefore seen immediately.

## Performance

The presented solution exhibits the following performance characteristics:

* Back-to-back push operations may take place independent of addressed context.

* Back-to-back pop operations are allowed only to differing contexts.

* Pop operations to the same context incur a one-cycle stall penalty. Dependency
  logic in the pipeline detects this condition automatically and asserts
  flow-contorl as necessary.

* The queue may consume one command per cycle, where a command is either a PUSH
  or a POP.
