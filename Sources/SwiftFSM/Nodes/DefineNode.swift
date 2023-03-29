//
//  DefineNode.swift
//
//  Created by Daniel Segall on 14/03/2023.
//

import Foundation

final class DefineNode: NeverEmptyNode {
    typealias Output = (state: AnyTraceable,
                        match: Match,
                        event: AnyTraceable,
                        nextState: AnyTraceable,
                        actions: [Action],
                        onEntry: [Action],
                        onExit: [Action])
    
    let onEntry: [Action]
    let onExit: [Action]
    var rest: [any Node<GivenNode.Output>] = []
    
    let caller: String
    let file: String
    let line: Int
        
    private var errors: [Error] = []
    
    init(
        onEntry: [Action],
        onExit: [Action],
        rest: [any Node<GivenNode.Output>] = [],
        caller: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        self.onEntry = onEntry
        self.onExit = onExit
        self.rest = rest
        self.caller = caller
        self.file = file
        self.line = line
    }
    
    func combinedWithRest(_ rest: [GivenNode.Output]) -> [Output] {
        let output = rest.reduce(into: []) {
            $0.append(
                (state: $1.state,
                 match: finalised($1.match),
                 event: $1.event,
                 nextState: $1.nextState,
                 actions: $1.actions,
                 onEntry: onEntry,
                 onExit: onExit)
            )
        }
        
        return errors.isEmpty ? output : []
    }
    
    private func finalised(_ m: Match) -> Match {
        switch m.finalised() {
        case .failure(let e): errors.append(e); return Match()
        case .success(let m): return m
        }
    }
    
    func validate() -> [Error] {
        makeError(if: rest.isEmpty) + errors
    }
}
