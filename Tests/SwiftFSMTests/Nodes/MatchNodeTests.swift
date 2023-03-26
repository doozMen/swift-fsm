//
//  MatchNodeTests.swift
//
//  Created by Daniel Segall on 20/03/2023.
//

import XCTest
@testable import SwiftFSM

final class MatchNodeTests: SyntaxNodeTests {
    func testEmptyMatchNodeIsNotError() {
        XCTAssertEqual(0, MatchNode(match: Match(), rest: []).finalised().errors.count)
    }
    
    func testEmptyMatchBlockNodeIsError() {
        assertEmptyNodeWithError(MatchBlockNode(match: Match(), rest: []))
    }
    
    func testEmptyMatchBlockNodeHasNoOutput() {
        assertCount(MatchBlockNode(match: Match(), rest: []).finalised().output, expected: 0)
    }
    
    func testMatchNodeFinalisesCorrectly() {
        assertMatch(MatchNode(match: Match(), rest: [whenNode]))
    }
    
    func testMatchNodeWithChainFinalisesCorrectly() {
        let m = MatchNode(match: Match(any: S.b, all: R.a))
        assertDefaultIONodeChains(node: m, expectedMatch: Match(any: [[P.a], [S.b]],
                                                        all: Q.a, R.a))
    }
    
    func testMatchNodeCanSetRestAfterInit() {
        let m = MatchNode(match: Match())
        m.rest.append(whenNode)
        assertMatch(m)
    }
}
