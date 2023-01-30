//
//  FSMTests.swift
//  FiniteStateMachineTests
//
//  Created by Daniel Segall on 29/01/2023.
//

import Foundation
import XCTest
@testable import FiniteStateMachine

class FSMTests: GenericTests {
    var didPass = false
    
    func pass() {
        didPass = true
    }
    
    func fail() {
        XCTFail()
    }
    
    func testHandlEvent() {
        let fsm = GenericFSM<State, Event>(initialState: .a)
        fsm.buildTransitions {
            Given(.a) | When(.h) | Then(.b) | Action(fail)
            Given(.a) | When(.g) | Then(.c) | Action(pass)
        }
        fsm.handleEvent(.g)
        XCTAssertTrue(didPass)
        XCTAssertEqual(fsm.state, .c)
    }
}