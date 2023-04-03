//
//  Define.swift
//
//  Created by Daniel Segall on 07/03/2023.
//

import Foundation

extension Syntax {
    struct Define<State: Hashable> {
        let node: DefineNode
        
        init(_ state: State,
             superStates: SuperState,
             _ rest: SuperState...,
             onEntry: [() -> ()],
             onExit: [() -> ()],
             file: String = #file,
             line: Int = #line
        ) {
            self.init(state,
                      superStates: [superStates] + rest,
                      onEntry: onEntry,
                      onExit: onExit,
                      elements: [],
                      file: file,
                      line: line)
        }
        
        init(_ state: State,
             superStates: SuperState...,
             onEntry: [() -> ()] = [],
             onExit: [() -> ()] = [],
             file: String = #file,
             line: Int = #line,
             @Internal.MWTABuilder _ block: () -> [any MWTA]
        ) {
            self.init(state: state,
                      superStates: superStates,
                      onEntry: onEntry,
                      onExit: onExit,
                      file: file,
                      line: line,
                      block)
        }
        
        init(state: State,
             superStates: [SuperState] = [],
             onEntry: [() -> ()],
             onExit: [() -> ()],
             file: String = #file,
             line: Int = #line,
             @Internal.MWTABuilder _ block: () -> [any MWTA]
        ) {
            let elements = block()
            
            self.init(state,
                      superStates: elements.isEmpty ? [] : superStates,
                      onEntry: onEntry,
                      onExit: onExit,
                      elements: elements,
                      file: file,
                      line: line)
        }
        
        init(_ state: State,
             superStates: [SuperState],
             onEntry: [() -> ()],
             onExit: [() -> ()],
             elements: [any MWTA],
             file: String = #file,
             line: Int = #line
        ) {
            let onEntry = onEntry + superStates.map(\.entryActions).flattened
            let onExit = onExit + superStates.map(\.exitActions).flattened
            
            let dNode = DefineNode(onEntry: onEntry,
                                   onExit: onExit,
                                   caller: "define",
                                   file: file,
                                   line: line)
            
            let isValid = !superStates.isEmpty || !elements.isEmpty
            
            if isValid {
                func eraseToAnyTraceable(_ s: State) -> AnyTraceable {
                    AnyTraceable(s, file: file, line: line)
                }
                
                let state = AnyTraceable(state, file: file, line: line)
                let rest = superStates.map(\.nodes).flattened + elements.nodes
                let gNode = GivenNode(states: [state], rest: rest)
                
                dNode.rest = [gNode]
            }
            
            self.node = dNode
        }
    }
}
