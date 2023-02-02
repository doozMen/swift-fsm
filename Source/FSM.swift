//
//  FSM.swift
//  FiniteStateMachineTests
//
//  Created by Daniel Segall on 29/01/2023.
//

import Foundation

class FSMBase<State, Event> where State: StateProtocol, Event: EventProtocol {
    typealias T = Transition<State, Event>
    typealias K = T.Key
    
    var state: State
    var transitions = [K: T]()
    
    fileprivate init(initialState state: State) {
        self.state = state
    }
    
    fileprivate func _handleEvent(_ event: Event) {
        let key = K(state: state, event: event)
        if let t = transitions[key] {
            t.actions.forEach { $0() }
            state = t.nextState
        }
    }
    
    func buildTransitions(@T.Builder _ content: () -> [T]) throws {
        var keys = Set([K]())
        var invalidTransitions = Set([T]())
        
        let transitions = content().reduce(into: [K: T]()) {
            let k = K(state: $1.givenState, event: $1.event)
            if keys.contains(k) {
                invalidTransitions.insert($0[k]!)
                invalidTransitions.insert($1)
            }
            else {
                keys.insert(k)
                $0[k] = $1
            }
        }
        
        guard invalidTransitions.isEmpty else {
            try throwError(invalidTransitions)
        }
        
        self.transitions = transitions
    }
    
    func throwError(_ ts: Set<T>) throws -> Never {
        let message =
"""
The same 'given-when' combination cannot lead to more than one 'then' state.

The following conflicts were found:
"""
        let conflicts = ts
            .map { "\n\($0.givenState) | \($0.event) | *\($0.nextState)*" }
            .sorted()
            .joined()
        throw ConflictingTransitionError(message + conflicts)
    }
}

#warning("Should this also throw for duplicate valid transitions?")

struct ConflictingTransitionError: Error {
    let localizedDescription: String
    
    init(_ localizedDescription: String) {
        self.localizedDescription = localizedDescription
    }
}

final class FSM<State, Event>: FSMBase<State, Event> where State: StateProtocol, Event: EventProtocol {
    override init(initialState state: State) {
        super.init(initialState: state)
    }
    
    func handleEvent(_ event: Event) {
        _handleEvent(event)
    }
}

final class UnsafeFSM: FSMBase<Unsafe.AnyState, Unsafe.AnyEvent> {
    init(initialState state: any StateProtocol) {
        super.init(initialState: state.erased)
    }
    
    func handleEvent(_ event: any EventProtocol) {
        _handleEvent(event.erased)
    }
}
