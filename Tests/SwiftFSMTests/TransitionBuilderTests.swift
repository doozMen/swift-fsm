//
//  TransitionBuilderTests.swift
//
//  Created by Daniel Segall on 03/03/2023.
//

import Foundation
import XCTest
@testable import SwiftFSM

final class SyntaxBuilderTests: XCTestCase, TransitionBuilder {
    typealias State = Int
    typealias Event = Int
    
    typealias Matching = Syntax.Matching
    typealias Then = Syntax.Then
    typealias When = Syntax.When
    
    func assertMatching(
        _ m: Syntax.Matching,
        any: any Predicate...,
        all: any Predicate...,
        sutLine: Int,
        xctLine: UInt = #line
    ) {
        XCTAssertTrue(m.node.rest.isEmpty, line: xctLine)
        assertMatching(m.node, any: any, all: all, sutLine: sutLine, xctLine: xctLine)
    }
    
    func assertMatching(
        _ node: MatchNode,
        any: [any Predicate] = [],
        all: [any Predicate] = [],
        sutLine: Int,
        xctLine: UInt = #line
    ) {
        XCTAssertEqual(any.erase(), node.match.matchAny, line: xctLine)
        XCTAssertEqual(all.erase(), node.match.matchAll, line: xctLine)
        
        XCTAssertEqual(#file, node.file, line: xctLine)
        XCTAssertEqual(sutLine, node.line, line: xctLine)
        XCTAssertEqual("match", node.caller, line: xctLine)
    }
    
    func testMatch() {
        let m1 = matching(P.a); let l1 = #line
        let m2 = Matching(P.a); let l2 = #line
        
        assertMatching(m1, all: P.a, sutLine: l1)
        assertMatching(m2, all: P.a, sutLine: l2)
        
        let m3 = matching(any: P.a, P.b); let l3 = #line
        let m4 = Matching(any: P.a, P.b); let l4 = #line

        assertMatching(m3, any: P.a, P.b, sutLine: l3)
        assertMatching(m4, any: P.a, P.b, sutLine: l4)
        
        let m5 = matching(all: P.a, Q.a); let l5 = #line
        let m6 = Matching(all: P.a, Q.a); let l6 = #line
        
        assertMatching(m5, all: P.a, Q.a, sutLine: l5)
        assertMatching(m6, all: P.a, Q.a, sutLine: l6)
        
        let m7 = matching(any: P.a, P.b, all: Q.a, R.a); let l7 = #line
        let m8 = Matching(any: P.a, P.b, all: Q.a, R.a); let l8 = #line
        
        assertMatching(m7, any: P.a, P.b, all: Q.a, R.a, sutLine: l7)
        assertMatching(m8, any: P.a, P.b, all: Q.a, R.a, sutLine: l8)
    }
        
    func assertWhen<E>(_ w: When<E>, sutLine: Int, xctLine: UInt = #line) {
        XCTAssertTrue(w.node.rest.isEmpty, line: xctLine)
        assertWhen(w.node, sutLine: sutLine, xctLine: xctLine)
    }
    
    func assertWhen(_ node: WhenNode, sutLine: Int, xctLine: UInt = #line) {
        XCTAssertEqual([1, 2], node.events.map(\.base), line: xctLine)
        XCTAssertEqual([#file, #file], node.events.map(\.file), line: xctLine)
        XCTAssertEqual([sutLine, sutLine], node.events.map(\.line), line: xctLine)
        
        XCTAssertEqual(#file, node.file, line: xctLine)
        XCTAssertEqual(sutLine, node.line, line: xctLine)
        XCTAssertEqual("when", node.caller, line: xctLine)
    }
    
    func testWhen() {
        
        let w1 = when(1, 2); let l1 = #line
        let w2 = When(1, 2); let l2 = #line
        
        assertWhen(w1, sutLine: l1)
        assertWhen(w2, sutLine: l2)
    }
    
    func assertThen(
        _ n: ThenNode,
        state: State?,
        sutLine: Int?,
        file: String? = nil,
        xctLine: UInt = #line
    ) {
        XCTAssertEqual(state, n.state?.base as? State, line: xctLine)
        XCTAssertEqual(file, n.state?.file, line: xctLine)
        XCTAssertEqual(sutLine, n.state?.line, line: xctLine)
    }
    
    func testThen() {
        let n1 = then(1).node; let l1 = #line
        let n2 = Then(1).node; let l2 = #line
        
        let n3 = then().node
        let n4 = Then<AnyHashable>().node
        
        assertThen(n1, state: 1, sutLine: l1, file: #file)
        assertThen(n2, state: 1, sutLine: l2, file: #file)

        assertThen(n3, state: nil, sutLine: nil)
        assertThen(n4, state: nil, sutLine: nil)
    }

    var output = ""
    
    func assertActions(
        _ n: ActionsNode,
        output: String,
        state: State?,
        sutLine: Int?,
        file: String? = nil,
        xctLine: UInt = #line
    ) {
        let thenNode = n.rest.first as! ThenNode
        n.actions.executeAll()
        assertThen(thenNode, state: state, sutLine: sutLine, file: #file, xctLine: xctLine)
        XCTAssertEqual(output, self.output, line: xctLine)
        self.output = ""
    }
    
    func testThenActions() {
        func action() {
            output = "pass"
        }
        
        let n1 = then(1) | { self.output = "pass" }; let l1 = #line
        let n2 = Then(1) | { self.output = "pass" }; let l2 = #line
         
        assertActions(n1.node, output: "pass", state: 1, sutLine: l1)
        assertActions(n2.node, output: "pass", state: 1, sutLine: l2)
        
        let n3 = then(1) | { }; let l3 = #line
        let n4 = Then(1) | { }; let l4 = #line
        
        assertActions(n3.node, output: "", state: 1, sutLine: l3)
        assertActions(n4.node, output: "", state: 1, sutLine: l4)
        
        let n5 = then(1) | action ; let l5 = #line
        let n6 = Then(1) | action ; let l6 = #line
        
        assertActions(n5.node, output: "pass", state: 1, sutLine: l5)
        assertActions(n6.node, output: "pass", state: 1, sutLine: l6)
    }
    
    func testMatchingWhen() {
        func assertMatchingWhen(_ mw: Syntax._MatchingWhen, sutLine: Int, xctLine: UInt = #line) {
            let whenNode = mw.node
            let matchNode = whenNode.rest.first as! MatchNode
            
            XCTAssertEqual(1, whenNode.rest.count, line: xctLine)
            XCTAssertEqual(0, matchNode.rest.count, line: xctLine)
            
            assertWhen(whenNode, sutLine: sutLine, xctLine: xctLine)
            assertMatching(matchNode, all: [P.a], sutLine: sutLine, xctLine: xctLine)
        }
        
        let mw1 = matching(P.a) | when(1, 2); let l1 = #line
        let mw2 = Matching(P.a) | When(1, 2); let l2 = #line

        assertMatchingWhen(mw1, sutLine: l1)
        assertMatchingWhen(mw2, sutLine: l2)
    }
    
    func testMatchingWhenThen() {
        func assertMatchingWhenThen(
            _ mwt: Syntax._MatchingWhenThen,
            sutLine: Int,
            xctLine: UInt = #line
        ) {
            let then = mwt.node
            let when = then.rest.first as! WhenNode
            let match = when.rest.first as! MatchNode
            
            XCTAssertEqual(1, then.rest.count, line: xctLine)
            XCTAssertEqual(1, when.rest.count, line: xctLine)
            XCTAssertEqual(0, match.rest.count, line: xctLine)
            
            assertThen(then, state: 1, sutLine: sutLine, file: #file, xctLine: xctLine)
            assertWhen(when, sutLine: sutLine, xctLine: xctLine)
            assertMatching(match, all: [P.a], sutLine: sutLine, xctLine: xctLine)
        }
        
        let mwt1 = matching(P.a) | when(1, 2) | then(1); let l1 = #line
        let mwt2 = Matching(P.a) | When(1, 2) | Then(1); let l2 = #line

        assertMatchingWhenThen(mwt1, sutLine: l1)
        assertMatchingWhenThen(mwt2, sutLine: l2)
    }
    
    func pass() { output = "pass" }
    
    func assertMatchingWhenThenActions(
        _ mwta: Syntax._MatchingWhenThenActions,
        sutLine: Int,
        xctLine: UInt = #line
    ) {
        let actions = mwta.node
        let then = actions.rest.first as! ThenNode
        let when = then.rest.first as! WhenNode
        let match = when.rest.first as! MatchNode
        
        XCTAssertEqual(1, actions.rest.count, line: xctLine)
        XCTAssertEqual(1, then.rest.count, line: xctLine)
        XCTAssertEqual(1, when.rest.count, line: xctLine)
        XCTAssertEqual(0, match.rest.count, line: xctLine)
        
        assertActions(actions, output: "pass", state: 1, sutLine: sutLine, xctLine: xctLine)
        assertThen(then, state: 1, sutLine: sutLine, file: #file, xctLine: xctLine)
        assertWhen(when, sutLine: sutLine, xctLine: xctLine)
        assertMatching(match, all: [P.a], sutLine: sutLine, xctLine: xctLine)
    }
    
    func testMatchingWhenThenActions() {
        let mwta1 = matching(P.a) | when(1, 2) | then(1) | pass; let l1 = #line
        let mwta2 = Matching(P.a) | When(1, 2) | Then(1) | pass; let l2 = #line

        assertMatchingWhenThenActions(mwta1, sutLine: l1)
        assertMatchingWhenThenActions(mwta2, sutLine: l2)
    }
    
    func testWhenThen() {
        func assertWhenThen(
            _ wt: Syntax._WhenThen,
            sutLine: Int,
            xctLine: UInt = #line
        ) {
            let then = wt.node
            let when = then.rest.first as! WhenNode
            
            XCTAssertEqual(1, then.rest.count, line: xctLine)
            XCTAssertEqual(0, when.rest.count, line: xctLine)
            
            assertThen(then, state: 1, sutLine: sutLine, file: #file, xctLine: xctLine)
            assertWhen(when, sutLine: sutLine, xctLine: xctLine)
        }
        
        let wt1 = when(1, 2) | then(1); let l1 = #line
        let wt2 = When(1, 2) | Then(1); let l2 = #line
        
        assertWhenThen(wt1, sutLine: l1)
        assertWhenThen(wt2, sutLine: l2)
    }
    
    func assertWhenThenActions(
        _ wta: Syntax._WhenThenActions,
        sutLine: Int,
        xctLine: UInt = #line
    ) {
        let actions = wta.node
        let then = actions.rest.first as! ThenNode
        let when = then.rest.first as! WhenNode
        
        XCTAssertEqual(1, actions.rest.count, line: xctLine)
        XCTAssertEqual(1, then.rest.count, line: xctLine)
        XCTAssertEqual(0, when.rest.count, line: xctLine)
        
        assertActions(actions, output: "pass", state: 1, sutLine: sutLine, xctLine: xctLine)
        assertThen(then, state: 1, sutLine: sutLine, file: #file, xctLine: xctLine)
        assertWhen(when, sutLine: sutLine, xctLine: xctLine)
    }
    
    func testWhenThenActions() {
        let wta1 = when(1, 2) | then(1) | pass; let l1 = #line
        let wta2 = When(1, 2) | Then(1) | pass; let l2 = #line
        
        assertWhenThenActions(wta1, sutLine: l1)
        assertWhenThenActions(wta2, sutLine: l2)
    }
    
    func testMWTABuilder() {
        func build(@Syntax._MWTABuilder _ block: () -> ([any SyntaxNode])) -> [any SyntaxNode] {
            block()
        }
        
        func assertResult(_ result: [any SyntaxNode], sutLine: Int, xctLine: UInt = #line) {
            let mwta = result[0] as! Syntax._MatchingWhenThenActions
            let wta = result[1] as! Syntax._WhenThenActions
            
            assertMatchingWhenThenActions(mwta, sutLine: sutLine, xctLine: xctLine)
            assertWhenThenActions(wta, sutLine: sutLine + 1, xctLine: xctLine)
        }
        
        let l1 = #line + 1; let s1 = build {
            matching(P.a) | when(1, 2) | then(1) | pass
            when(1, 2) | then(1) | pass
        }
        
        assertResult(s1, sutLine: l1)
        
        let l2 = #line + 1; let s2 = build {
            Matching(P.a) | When(1, 2) | Then(1) | pass
            When(1, 2) | Then(1) | pass
        }
        
        assertResult(s2, sutLine: l2)
    }
}