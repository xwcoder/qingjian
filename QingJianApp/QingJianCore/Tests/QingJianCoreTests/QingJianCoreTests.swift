//
//  QingJianCoreTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//

import XCTest
@testable import QingJianCore

final class QingJianCoreTests: XCTestCase {
    
    func testVersionNotEmpty() {
        XCTAssertFalse(QingJianCore.version.isEmpty)
    }
    
    func testBuildInfo() {
        let info = QingJianCore.buildInfo
        XCTAssertTrue(info == "Debug" || info == "Release")
    }
}
