//
//  ThenNodeTests.swift
//
//  Created by Daniel Segall on 20/03/2023.
//

import XCTest
@testable import SwiftFSM

final class ThenNodeTests: SyntaxNodeTests {
    func testNilThenNodeState() {
        assertEmptyThen(
            ThenNode(state: nil, rest: []),
            thenState: nil
        )
    }
    
    func testEmptyThenNode() {
        assertEmptyThen(
            ThenNode(state: s1, rest: [])
        )
    }
    
    func testThenNodeWithEmptyRest() {
        assertEmptyThen(
            ThenNode(state: s1,
                     rest: [ActionsNode(actions: [])])
        )
    }
    
    func testEmptyThenBlockNode() {
        assertEmptyNodeWithError(ThenBlockNode(state: s1, rest: []))
    }
    
    func testThenNodeFinalisesCorrectly() {
        assertThenWithActions(
            expected: "12",
            ThenNode(state: s1, rest: [actionsNode])
        )
    }
    
    func testThenNodePlusChainFinalisesCorrectly() {
        let t = ThenNode(state: s2)
        assertDefaultIONodeChains(node: t, expectedState: s2)
    }
    
    func testThenNodeCanSetRestAfterInit() {
        let t = ThenNode(state: s1)
        t.rest.append(actionsNode)
        assertThenWithActions(expected: "12", t)
    }
    
    func testThenNodeFinalisesWithMultipleActionsNodes() {
        assertThenWithActions(
            expected: "1212",
            ThenNode(state: s1, rest: [actionsNode,
                                       actionsNode])
        )
    }
}
