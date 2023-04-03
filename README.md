# Swift FSM
### Friendly Finite State Machine Syntax for Swift, iOS and macOS

Inspired by [Uncle Bob's SMC][1] syntax, Swift FSM is a pure Swift syntax for declaring and operating a Finite State Machine (FSM). Unlike Uncle Bob’s SMC, the FSM itself is declared inside your Swift code, rather than as a separate text file, and compiles and runs directly alongside all your other project code.

This guide is reasonably complete, but does presume some familiarity with FSMs and specifically the SMC syntax linked above.

## Contents

- [Requirements][2]
- [Basic Syntax][3]
	- [Optional Arguments][4]
	- [Super States][5]
	- [Entry and Exit Actions][6]
	- [Syntax Order][7]
	- [Syntax Variations][8]
	- [Syntactic Sugar][9]
	- [Performance][10]
- [Expanded Syntax][11]
	- [Rationale][12]
	- [Example][13]
	- [Detailed Description][14]
		- [Implicit Matching Statements][15]
		- [Multiple Predicates][16]
		- [Implicit Conflicts][17]
		- [Deduplication][18]
		- [Chained Blocks][19]
		- [Complex Predicates][20]
		- [Predicate Performance][21]
		- [Error Handling][22]

## Requirements

Swift FSM is a Swift package, importable through the Swift Package Manager, and requires macOS 12.6 and/or iOS 15.6 or later, alongside Swift 5.6 or later.

## Basic Syntax

Borrowing from SMC, we have an example of a simple subway turnstile system. This turnstile currently has two possible states: `Locked`, and `Unlocked`, alongside two possible events: `Coin`, and `Pass`.

The logic is as follows (from Uncle Bob, emphasis added): 

> - *Given* we are in the *Locked* state, *when* we get a *Coin* event, *then* we transition to the *Unlocked* state and *invoke* the *unlock* action.
> - *Given* we are in the *Locked* state, *when* we get a *Pass* event, *then* we stay in the *Locked* state and *invoke* the *alarm* action.
> - *Given* we are in the *Unlocked* state, *when* we get a *Coin* event, *then* we stay in the *Unlocked* state and *invoke* the *thankyou* action.
> - *GIven* we are in the *Unlocked* state, *when* we get a *Pass* event, *then* we transition to the *Locked* state and *invoke* the *lock* action.

Following Uncle Bob’s examples, we will build up our table bit by bit to demonstrate the different syntactic possibilities of Swift FSM:

SMC:

```
Initial: Locked
FSM: Turnstile
{
  Locked    {
    Coin    Unlocked    unlock
    Pass    Locked      alarm
  }
  Unlocked  {
    Coin    Unlocked    thankyou
    Pass    Locked      lock
  }
}
```

Swift FSM (with additional code for context):

```swift
import SwiftFSM

class MyClass: SyntaxBuilder {
    enum State { case locked, unlocked }
    enum Event { case coin, pass }

    let fsm = FSM<State, Event>(initialState: .locked)

    func myMethod() {
        try! fsm.buildTable {
            define(.locked) {
                when(.coin) | then(.unlocked) | unlock
                when(.pass) | then(.locked)   | alarm
            }

            define(.unlocked) {
                when(.coin) | then(.unlocked) | thankyou
                when(.pass) | then(.locked)   | lock
            }
        }

        fsm.handleEvent(.coin)
    }
}
```

Here we can see the four natural language sentences translated into a minimalistic syntax capable of expressing their essential logic.

```swift
class MyClass: SyntaxBuilder {
```

The `SyntaxBuilder` protocol provides the methods `define`, `when`, and `then` necessary to build the transition table. It has two associated types, `State` and `Event`, which must be `Hashable`.

```swift
let fsm = FSM<State, Event>(initialState: .locked)
```

`FSM` is generic  over `State` and `Event`.  As with `SyntaxBuilder`, `State` and `Event` must be `Hashable`. Here we have used an `Enum`, specifying the initial state of the FSM as `.locked`.

```swift
try! fsm.buildTable {
```

`fsm.buildTable` is a throwing function - though the type system will prevent various illogical statements, there are some issues that can only be detected at runtime.

```swift
define(.locked) {
```

The `define` statement roughly corresponds to the ‘Given’ keyword in the natural language description of the FSM. It is expected however that you will only write one `define` per state.

`define` takes two arguments - a `State` instance, and a Swift `@resultBuilder` block.

```swift
when(.coin) | then(.unlocked) | unlock
```

As we are inside a `define` block, we take the `.locked` state as a given. We can now list our transitions, with each line representing a single transition. In this case, `when` we receive a `.coin` event, we will `then` transition to the `.unlocked` state and call `unlock`. 

`unlock` is a function, also declarable as follows:

```swift
when(.coin) | then(.unlocked) | { unlock() //; otherFunction(); etc. }
```

The `|` (pipe) operator binds transitions together. It feeds the output of the left hand side into the input of the right hand side, as you might expect in a terminal.

```swift
fsm.handleEvent(.coin)
```

The `FSM` instance will look up the appropriate transition for its current state, call the associated function, and transition to the associated next state. In this case, the `FSM` will call the `unlock` function and transition to the `unlocked` state.  If no transition is found, it will do nothing.

### Optional Arguments

> Now let's add an Alarming state that must be reset by a repairman:

SMC:

```
Initial: Locked
FSM: Turnstile
{
  Locked    {
    Coin    Unlocked    unlock
    Pass    Alarming    alarmOn
    Reset   -           {alarmOff lock}
  }
  Unlocked  {
    Reset   Locked      {alarmOff lock}
    Coin    Unlocked    thankyou
    Pass    Locked      lock
  }
  Alarming {
    Coin    -          -
    Pass    -          -  
    Reset   Locked     {alarmOff lock}
  }
}
```

Swift FSM:

```swift
try! fsm.buildTable {
    define(.locked) {
        when(.coin)  | then(.unlocked) | unlock
        when(.pass)  | then(.alarming) | alarmOn
        when(.reset) | then()          | { alarmOff(); lock() }
    }

    define(.unlocked) {
        when(.reset) | then(.locked)   | { alarmOff(); lock() }
        when(.coin)  | then(.unlocked) | thankyou
        when(.pass)  | then(.locked)   | lock
    }

    define(.alarming) {
        when(.coin)  | then()
        when(.pass)  | then()
        when(.reset) | then(.locked) | { alarmOff(); lock() }
    }
}
```

`then()` with no argument means ‘no change’, and the FSM will remain in the current state.  The actions pipe is also optional - if a transition performs no actions, it can be omitted.

### Super States:

> Notice the duplication of the Reset transition. In all three states the Reset event does the same thing. It transitions to the Locked state and it invokes the lock and alarmOff actions. This duplication can be eliminated by using a Super State as follows:

SMC:

```
Initial: Locked
FSM: Turnstile
{
  // This is an abstract super state.
  (Resetable)  {
    Reset       Locked       {alarmOff lock}
  }
  Locked : Resetable    { 
    Coin    Unlocked    unlock
    Pass    Alarming    alarmOn
  }
  Unlocked : Resetable {
    Coin    Unlocked    thankyou
    Pass    Locked      lock
  }
  Alarming : Resetable { // inherits all it's transitions from Resetable.
  }
}
```

Swift FSM:

```swift
try! fsm.buildTable {
    let resetable = SuperState {
        when(.reset) | then(.locked) | { alarmOff(); lock() }
    }

    define(.locked, superStates: resetable) {
        when(.coin) | then(.unlocked) | unlock
        when(.pass) | then(.alarming) | alarmOn
    }

    define(.unlocked, superStates: resetable) {
        when(.coin) | then(.unlocked) | thankyou
        when(.pass) | then(.locked)   | lock
    }

    define(.alarming, superState: resetable)
}
```

`SuperState`  takes a `@resultBuilder` block like `define`, however it does not take a starting state. The starting state is taken from the `define` statement to which it is passed. Passing `SuperState` instances to a `define` call will add the transitions declared in each of the `SuperState` instances to the other transitions declared in the `define`. 

If a `SuperState` instance is given, the `@resultBuilder` argument to `define` is optional.

`SuperState` instances themselves can accept other `SuperState` instances, and will combine them together in the same way as `define`:

```swift
let s1 = SuperState { when(.coin) | then(.unlocked) | unlock  }
let s2 = SuperState { when(.pass) | then(.alarming) | alarmOn }

let s3 = SuperState(superStates: s1, s2)

// s3 is equivalent to:

let s4 = SuperState {
    when(.coin) | then(.unlocked) | unlock
    when(.pass) | then(.alarming) | alarmOn
}
```

**Important** - SMC allows for both abstract (without a given state) and concrete (with a given state) Super States. It also allows for overriding transitions declared in a Super State. Swift FSM on the other hand only allows abstract Super States, defined using the `SuperState` struct, and any attempt to override a Super State transition will result in a duplicate transition error.

### Entry and Exit Actions

> In the previous example, the fact that the alarm is turned on every time the Alarming state is entered and is turned off every time the Alarming state is exited, is hidden within the logic of several different transitions. We can make it explicit by using entry actions and exit actions.

SMC:

```
Initial: Locked
FSM: Turnstile
{
  (Resetable) {
    Reset       Locked       -
  }
  Locked : Resetable <lock     {
    Coin    Unlocked    -
    Pass    Alarming    -
  }
  Unlocked : Resetable <unlock  {
    Coin    Unlocked    thankyou
    Pass    Locked      -
  }
  Alarming : Resetable <alarmOn >alarmOff   -    -    -
}
```

Swift FSM:

```swift
try fsm.buildTable {
    let resetable = SuperState {
        when(.reset) | then(.locked)
    }

    define(.locked, superStates: resetable, onEntry: [lock]) {
        when(.coin) | then(.unlocked)
        when(.pass) | then(.alarming)
    }

    define(.unlocked, superStates: resetable, onEntry: [unlock]) {
        when(.coin) | then(.unlocked) | thankyou
        when(.pass) | then(.locked)
    }

    define(.alarming, superStates: resetable, onEntry: [alarmOn], onExit: [alarmOff])
}
```

`onEntry` and `onExit` are the final arguments to `define` and specify an array of entry and exit actions to be performed when entering or leaving the defined state.

`SuperState` instances can also accept entry and exit actions:

```swift
let resetable = SuperState(onEntry: [lock]) {
    when(.reset) | then(.locked)
}

define(.locked, superStates: resetable) {
    when(.coin) | then(.unlocked)
    when(.pass) | then(.alarming)
}

// equivalent to:

define(.locked, onEntry: [lock]) {
    when(.reset) | then(.locked)
    when(.coin)  | then(.unlocked)
    when(.pass)  | then(.alarming)
}
```

`SuperState` instances also inherit entry and exit actions from their superstates:

```swift
let s1 = SuperState(onEntry: [unlock])  { when(.coin) | then(.unlocked) }
let s2 = SuperState(onEntry: [alarmOn]) { when(.pass) | then(.alarming) }

let s3 = SuperState(superStates: s1, s2)

// s3 is equivalent to:

let s4 = SuperState(onEntry: [unlock, alarmOn]) { 
    when(.coin) | then(.unlocked)
    when(.pass) | then(.alarming)
}
```

**Important** - in SMC, entry and exit actions are invoked even if the state does not change. In the example above, this would mean that the unlock entry action would be called on all transitions into the `Unlocked` state, *even if the FSM is already in the `Unlocked` state*. 

In contrast, Swift FSM entry and exit actions are only invoked if there is a state change. In the example above, this means that, in the `.unlocked` state, after a `.coin` event, `unlock` will *not* be called.

### Syntax Order

All statements must be made in the form `define { when | then | actions }`. Any reordering will not compile.

See [Expanded Syntax][23] below for exceptions to this rule.

### Syntax Variations

Swift FSM allows you to alter the naming conventions in your syntax by using `typealiases`. Though `define`, `when`, and `then` are functions, there are matching structs with equivalent capitalised names contained in the `SwiftFSM.Syntax` namespace.

Here is one minimalistic example:

```swift
typealias d = Syntax.Define<State>
typealias w = Syntax.When<Event>
typealias t = Syntax.Then<State>

try! fsm.buildTable {
    d(.locked) {
        w(.coin) | t(.unlocked) | unlock
        w(.pass) | t(.locked)   | alarm
    }

    d(.unlocked) {
        w(.coin) | t(.unlocked) | thankyou
        w(.pass) | t(.locked)   | lock
    }
}
```

It you wish to use this alternative syntax, it is strongly recommended that you *do not implement* `SyntaxBuilder`. Use the function syntax provided by `SyntaxBuilder`, *or* the struct syntax provided by the `Syntax` namespace. 

No harm will befall the FSM if you mix and match, but at the very least, from an autocomplete point of view, things will get messy. 

### Syntactic Sugar

 `when` statements accept vararg `Event` instances for convenience.

```swift
define(.locked) {
    when(.coin, or: .pass, ...) | then(.unlocked) | unlock
}

// equivalent to:

define(.locked) {
    when(.coin) | then(.unlocked) | unlock
    when(.pass) | then(.unlocked) | unlock
    ...
}
```

### Performance

Swift FSM uses a Dictionary to store the state transition table, and each time `handleEvent()` is called, it performs a single O(1) operation to find the correct transition. Though O(1) is ideal from a performance point of view, a O(1) lookup is still significantly slower than a nested switch case statement, and Swift FSM is approximately 2-3x slower per transition.

## Expanded Syntax

Swift FSM matches the syntax possibilities offered by SMC, however it also introduces some new possibilities of its own. None of this additional syntax is required, and is provided for convenience.

### Rationale

Though the turnstile is a pleasing example, it is also conveniently simple. Given that all computer programs are in essence FSMs, there is no limit to the degree of complexity an FSM table might reach. At some point on the complexity scale, SMC and Swift FSM basic syntax would become so lengthy as to be unusable.

### Example

Let’s imagine an extension to our turnstile rules, whereby under some circumstances, we might want to strongly enforce the ‘everyone pays’ rule by entering the alarming state if a `.pass` is detected when still in the `.locked` state, yet in others, perhaps at rush hour for example, we might want to be more permissive in order to avoid disruption to other passengers.

We could implement a check somewhere else in the system, perhaps inside the implementation of the `alarmOn` function to decide what the appropriate behaviour should be depending on the time of day.

But this comes with a problem - we now have some aspects of our state transitions declared inside the transition table, and other aspects declared elsewhere. Though this problem is inevitable in software, Swift FSM provides a mechanism to add some additional decision trees into the FSM table itself.

```swift
import SwiftFSM

class MyClass: ExpandedSyntaxBuilder {
    enum State { case locked, unlocked }
    enum Event { case coin, pass }
    enum Enforcement: Predicate { case weak, strong }

    let fsm = FSM<State, Event>(initialState: .locked)

    func myMethod() {
        try fsm.buildTable {
            ...
            define(.locked) {
                matching(Enforcement.weak)   | when(.pass) | then(.locked)   | doNothing
                matching(Enforcement.strong) | when(.pass) | then(.alarming) | makeAFuss
                
                when(.coin) | then(.unlocked)
            }
            ...

        }
        
        fsm.handleEvent(.pass, predicates: Enforcement.weak)
    }
}
```

Here we have introduced a new keyword `matching`, and two new protocols, `ExpandedTransitionBuilder` and `Predicate`. The define statement with its three sentences now reads as follows:

- Given that we are in the locked state:
	- If `Enforcement` is `.weak`, when we get a `.pass`, transition to `.locked`
	- If `Enforcement` is `.strong`, when we get a `.pass`, transition to `.alarming`
	- **Regardless** of `Enforcement`, when we get a `.coin`, transition to `.unlocked`

This allows the extra `Enforcement` logic to be expressed directly within the FSM table

### Detailed Description

`ExpandedSyntaxBuilder` inherits from `SyntaxBuilder`, providing all the SMC-equivalent syntax, whilst adding the new `matching` statements for working with predicates. For the `Struct` based variant syntax, the equivalent namespace is `SwiftFSM.Syntax.Expanded`.  

`Predicate` requires the conformer to be `Hashable` and `CaseIterable`. `CaseIterable` conformance allows the FSM to calculate all the possible cases of the `Predicate`, such that, if none is specified, it can match that statement to *any* of its cases. It is possible to use any type you wish, as long as your conformance to `Hashable` and `CaseIterable` makes logical sense. In practice however, this requirement is likely to limit `Predicates` to `Enums` without associated types, as these can be automatically conformed to `CaseIterable`. 

#### Implicit Matching Statements:

```swift
when(.coin) | then(.unlocked)
```

In the line above, no `Predicate` is specified, and its full meaning is therefore inferred from its context. The scope for predicate inference is the sum of the builder blocks for all `SuperState` and `define` calls inside `fsm.buildTable { }`.  

In this case, the type `Enforcement` appears in a `matching` statement elsewhere in the table, and Swift FSM will therefore to infer the absent `matching` statement as follows:

```swift
matching(Enforcement.weak)   | when(.coin) | then(.unlocked)
matching(Enforcement.strong) | when(.coin) | then(.unlocked)
```

Statements in Swift FSM are are therefore `Predicate` agnostic by default, and will match any given `Predicate`. In this way, `matching` statements are optional specifiers that *constrain* the transition to one or more specific `Predicate` cases. If no `Predicate` is specified, the statement will match all cases.

#### Multiple Predicates

Swift FSM does not limit the number of `Predicate` types that can be used in one table. The following (contrived and rather silly) expansion of the original `Predicate` example is equally valid:

```
enum Enforcement: Predicate { case weak, strong }
enum Reward: Predicate { case positive, negative }

try fsm.buildTable {
    ...
    define(.locked) {
        matching(Enforcement.weak)   | when(.pass) | then(.locked)   | lock
        matching(Enforcement.strong) | when(.pass) | then(.alarming) | alarmOn
                
        when(.coin) | then(.unlocked) | unlock
    }

    define(.unlocked) {
        matching(Reward.positive) | when(.coin) | then(.unlocked) | thankyou
        matching(Reward.negative) | when(.coin) | then(.unlocked) | idiot

        when(.coin) | then(.unlocked) | unlock
    }
    ...
}

fsm.handleEvent(.pass, predicates: Enforcement.weak, Reward.positive)
```

The same inference rules continue to apply:

```swift
when(.coin) | then(.unlocked)

// in two predicate context, now equivalent to:

matching(Enforcement.weak)   | when(.coin) | then(.unlocked)
matching(Enforcement.strong) | when(.coin) | then(.unlocked)
matching(Reward.positive)    | when(.coin) | then(.unlocked)
matching(Reward.negative)    | when(.coin) | then(.unlocked)
```

#### Implicit Conflicts

```swift
define(.locked) {
    matching(Enforcement.weak) | when(.coin) | then(.unlocked)
    matching(Reward.negative)  | when(.coin) | then(.locked)
}

// 💥 error: implicit conflict
```

On the surface of it, the two transitions above appear to be different from one another. However if we remember the inference rules, we will see that they actually conflict:

```swift
define(.locked) {
    matching(Enforcement.weak)    | when(.coin) | then(.unlocked) // clash 1
// also inferred as:
    matching(Reward.positive)     | when(.coin) | then(.unlocked)
    matching(Reward.negative)     | when(.coin) | then(.unlocked) // clash 2	

    matching(Reward.negative)     | when(.coin) | then(.locked)   // clash 2
// also inferred as:
    matching(Enforcement.weak)    | when(.coin) | then(.locked)   // clash 1
    matching(Enforcement.strong)  | when(.coin) | then(.locked)
```

#### Deduplication

In the following case, `when(.pass)` is duplicated:

```swift
matching(Enforcement.weak)   | when(.pass) | then(.locked)
matching(Enforcement.strong) | when(.pass) | then(.alarming)
```

 We can remove duplication as follows:

```swift
when(.pass) {
    matching(Enforcement.weak)   | then(.locked)
    matching(Enforcement.strong) | then(.alarming)
}
```

Here we have created a `when` context block. Anything in that context will assume that the event in question is `.pass`. 

The full example would now be:

```swift
try fsm.buildTable {
    ...
    define(.locked) {
        when(.pass) {
            matching(Enforcement.weak)   | then(.locked)
            matching(Enforcement.strong) | then(.alarming)
        }
                
        when(.coin) | then(.unlocked)
    }
    ...
}
```

`then` and `matching` support deduplication in a similar way:

```swift
try fsm.buildTable {
    ...
    define(.locked) {
        then(.unlocked) {
            when(.pass) {
                matching(Enforcement.weak)   | doSomething
                matching(Enforcement.strong) | doSomethingElse
            }
        }
    }
    ...
}
```

```swift
try fsm.buildTable {
    ...
    define(.locked) {
        matching(Enforcement.weak) {
            when(.coin) | then(.unlocked) | somethingWeak
            when(.pass) | then(.alarming) | somethingElseWeak
        }

        matching(Enforcement.strong) {
            when(.coin) | then(.unlocked) | somethingStrong
            when(.pass) | then(.alarming) | somethingElseStrong
        }
    }
    ...
}
```

The keyword `actions` is available for deduplicating function calls:

```swift
try fsm.buildTable {
    ...
    define(.locked) {
        actions(someCommonFunction) {
            when(.coin) | then(.unlocked)
            when(.pass) | then(.alarming)
        }
    }
    ...
}
```

#### Chained Blocks

Deduplication has introduced us to four blocks:

```swift
matching(predicate) { 
    // everything in scope matches 'predicate'
}

when(event) { 
    // everything in scope responds to 'event'
}

then(state) { 
    // everything in scope transitions to 'state'
}

actions(functionCalls) { 
   // everything in scope calls 'functionCalls'
}
```

They can be divided into two groups - blocks that can be logically chained (or AND-ed) together, and blocks that cannot.

##### Discrete Blocks - `when` and `then`

Each transition can only respond to a single event, and transition to a single state. Therefore multiple `when {}` and `then {}` blocks cannot be AND-ed together.

```swift
define(.locked) {
    when(.coin) {
        when(.pass) { } // ⛔️ does not compile
        when(.pass) | ... // ⛔️ does not compile

        matching(.something) | when(.pass) | ... // ⛔️ does not compile

        matching(.something) { 
            when(.pass) { } // ⛔️ does not compile
            when(.pass) | ... // ⛔️ does not compile
        }
    }

    then(.unlocked) {
        then(.locked) { } // ⛔️ does not compile
        then(.locked) | ... // ⛔️ does not compile

        matching(.something) | then(.locked) | ... // ⛔️ does not compile

        matching(.something) { 
            then(.locked) { } // ⛔️ does not compile
            then(.locked) | ... // ⛔️ does not compile
        }
    }      
}

```

Additionally, there is a specific combination of  `when` and `then` that does not compile:

```swift
define(.locked) {
    when(.coin) {
        then(.unlocked) | action // ⛔️ does not compile
        then(.locked)   | action // ⛔️ does not compile
    }
}
```

Logically, there is no situation where, in response to a single event (in this case, `.coin`), there could then be a transition to more than one state, unless a different `Predicate` is stated for each. 

Therefore the following is allowed:

```swift
define(.locked) {
    when(.coin) {
        matching(Enforcement.weak)   | then(.unlocked) | action // ✅
        matching(Enforcement.strong) | then(.locked)   | otherAction // ✅
    }
}
```

Note that by doing this, it is quite easy to form a duplicate that cannot be checked at compile time. For example:

```swift
define(.locked) {
    when(.coin) {
        matching(Enforcement.weak) | then(.unlocked) | action // ✅
        matching(Enforcement.weak) | then(.locked)   | otherAction // ✅
    }
}

// runtime error: logical clash
```

See the errors section for more information

##### Chainable Blocks - `matching` and `actions`

There is no logical restriction on the number of predicates or actions per transition, and therefore both can be built up in a chain as follows:

```swift
define(.locked) {
    matching(Enforcement.weak) {
        matching(Reward.positive) { } // ✅
        matching(Reward.positive) | ... // ✅
    }

    actions(doSomething) {
        actions(doSomethingElse) { } // ✅
        ... | doSomethingElse // ✅
    }      
}
```

Nested `actions` blocks sum the actions and perform all of them. In the above example, anything declared inside `actions(doSomethingElse) { }` will call both `doSomethingElse()` and `doSomething()`.

Nested `matching` blocks are AND-ed together. In the above example, anything declared inside `matching(Reward.positive) { }` will match both `Enforcement.weak` AND `Reward.positive`. 

##### Mixing blocks and pipes

Pipes can and must be used inside blocks, whereas blocks cannot be opened after pipes

```swift
define(.locked) {
    when(.coin) | then(.unlocked) { } // ⛔️ does not compile
    when(.coin) | then(.unlocked) | actions(doSomething) { } // ⛔️ does not compile
    matching(.something) | when(.coin) { } // ⛔️ does not compile
}
```

#### Complex Predicates

```swift
enum A: Predicate { case x, y, z }
enum B: Predicate { case x, y, z }
enum C: Predicate { case x, y, z }

matching(A.x)... // if A.x
matching(A.x, or: A.y)... // if A.x OR A.y
matching(A.x, or: A.y, A.z)... // if A.x OR A.y OR A.z

matching(A.x, and: B.x)... // if A.x AND B.x
matching(A.x, and: A.y)... // 💥 error: cannot match A.x and A.y simultaneously
matching(A.x, and: B.x, C.x)... // if A.x AND B.x AND C.x

matching(A.x, or: A.y, A.z, and: B.x, C.x)... // if (A.x OR A.y OR A.z) AND B.x AND C.x

fsm.handleEvent(.coin, predicates: A.x, B.x, C.x)
```

All of these `matching` statements can be used both with `|` syntax, and with deduplicating `{ }` syntax, as demonstrated with previous `matching` statements.

They should be reasonably self-explanatory, perhaps with the exception of why `matching(A.x, and: A.y)` is an error. 

In Swift FSM, the word ‘and’ means that we expect both predicates to be present *at the same time*. Each predicate type can only have one value at the time it is passed to `handleEvent()`, therefore asking it to match multiple values of the same `Predicate` type simultaneously has no meaning. The rules of the system are that, if `A.x` is current, `A.y` cannot also be current.

For clarity, it can be useful to think of `matching(A.x, and: A.y)` as meaning `matching(A.x, andSimultaneously: A.y)`. In terms of a `when` statement to which it is analogous, it would be as meaningless as saying `when(.coin, and: .pass)` - the event is either `.coin` or `.pass`, it cannot be both.

The word ‘or’ is more permissive - `matching(A.x, or: A.y)` can be thought of as `matching(anyOneOf: A.x, A.y)`.

**Important** - remember that nested `matching` statements are combined by AND-ing them together, which makes it particularly easy inadvertently to create a conflict.

```swift
define(.locked) {
    matching(A.x) {
        matching(A.y) {
            // 💥 error: cannot match A.x and A.y simultaneously 
        }
    }
}
```

This AND-ing behaviour also applies to OR statements: 

```swift
define(.locked) {
    matching(A.x, or: A.y) {
        matching(A.z) {
            // 💥 error: cannot match A.x and A.z simultaneously 
            // 💥 error: cannot match A.y and A.z simultaneously 
        }
    }
}
```

Nested OR statements that do not conflict are AND-ed as follows:

```swift
define(.locked) {
    matching(A.x, or: A.y) {
        matching(B.x, or: B.y) {
            // ✅ logically matches (A.x OR A.y) AND (B.x OR B.y)

            // internally translates to:

            // 1. matching(A.x, and: B.x)
            // 2. matching(A.x, and: B.y)
            // 3. matching(A.y, and: B.x)
            // 4. matching(A.y, and: B.y)
        }
    }
}
```

#### Predicate Performance

Adding predicates has no effect on the performance of `handleEvent()`. To maintain this performance, it does significant work ahead of time when creating the transition table, filling in missing transitions for all implied `Predicate` combinations.

The performance of `fsm.buildTransitions { }` is dominated by this, assuming any predicates are used at all. Because all possible combinations of cases of all given predicates have to be calculated, performance is O(m\*n) where m is the number of`Predicate` types, and n is the average number cases per `Predicate`.

Using three predicates, each with 10 cases each, would therefore require 1,000 operations to calculate all possible combinations.

#### Error Handling

In order to preserve performance, `fsm.handleEvent(event:predicates:)` performs no error handling. Therefore, passing in `Predicate` instances that do not appear anywhere in the transition table will not error. Nonetheless, the FSM will be unable to perform any transitions, as it will not contain any statements that match the given, unexpected `Predicate` instance. It is the caller’s responsibility to ensure that the predicates passed to `handleEvent` and the predicates used in the transition table are of the same type and number.

`try fsm.buildTable { }` does perform error handling to make sure the table is syntactically and semantically valid. In particular, it ensures that all `matching` statements are valid, and that there are no duplicate transitions and no logical clashes between transitions.

[1]:	https://github.com/unclebob/CC_SMC
[2]:	#requirements
[3]:	#basic-syntax
[4]:	#optional-arguments
[5]:	#super-states
[6]:	#entry-and-exit-actions
[7]:	#syntax-order
[8]:	#syntax-variations
[9]:	#syntactic-sugar
[10]:	#performance
[11]:	#expanded-syntax
[12]:	#rationale
[13]:	#example
[14]:	#detailed-description
[15]:	#implicit-matching-statements
[16]:	#multiple-predicates
[17]:	#implicit-conflicts
[18]:	#deduplication
[19]:	#chained-blocks
[20]:	#complex-predicates
[21]:	#predicate-performance
[22]:	#error-handling
[23]:	#expanded-syntax "Expanded Syntax"