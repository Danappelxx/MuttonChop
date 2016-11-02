import XCTest
@testable import MuttonChopTests

XCTMain([
    testCase(ReaderTests.allTests),
    testCase(ParserTests.allTests),
    testCase(CompilerTests.allTests),
    testCase(TemplateTests.allTests),

    testCase(CommentsTests.allTests),
    testCase(DelimitersTests.allTests),
    testCase(InterpolationTests.allTests),
    testCase(InvertedTests.allTests),
    testCase(PartialsTests.allTests),
    testCase(SectionsTests.allTests),
    testCase(InheritanceTests.allTests),
    testCase(TemplateCollectionTests.allTests),
])
