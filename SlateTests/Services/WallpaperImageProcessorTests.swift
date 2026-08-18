import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Slate

final class WallpaperImageProcessorTests: XCTestCase {
    private let processor = WallpaperImageProcessor()

    private func properties(of data: Data) throws -> NSDictionary {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil))
    }

    private func pixelSize(of data: Data) throws -> (width: Int, height: Int) {
        let properties = try properties(of: data)
        return (properties[kCGImagePropertyPixelWidth] as! Int, properties[kCGImagePropertyPixelHeight] as! Int)
    }

    func testRejectsNonImageData() async {
        do {
            _ = try await processor.process(Data("not-image".utf8))
            XCTFail("Expected wallpaper import to fail")
        } catch {
            XCTAssertEqual(error as? PlannerError, .wallpaperImport)
        }
    }

    func testRejectsEmptyData() async {
        do {
            _ = try await processor.process(Data())
            XCTFail("Expected wallpaper import to fail")
        } catch {
            XCTAssertEqual(error as? PlannerError, .wallpaperImport)
        }
    }

    func testDownsamplesAndStripsMetadata() async throws {
        let input = try ImageFixtures.jpeg(width: 5000, height: 3000, includeGPS: true)
        XCTAssertNotNil(try properties(of: input)[kCGImagePropertyGPSDictionary], "Fixture carries GPS metadata")

        let output = try await processor.process(input)
        let size = try pixelSize(of: output)
        XCTAssertLessThanOrEqual(max(size.width, size.height), 4096)
        XCTAssertGreaterThan(min(size.width, size.height), 0)
        XCTAssertEqual(Double(size.width) / Double(size.height), 5.0 / 3.0, accuracy: 0.01, "Aspect ratio is preserved")

        let properties = try properties(of: output)
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
        XCTAssertNil((properties[kCGImagePropertyTIFFDictionary] as? NSDictionary)?[kCGImagePropertyTIFFMake])
        XCTAssertNil((properties[kCGImagePropertyTIFFDictionary] as? NSDictionary)?[kCGImagePropertyTIFFModel])
        XCTAssertNil(properties[kCGImagePropertyExifDictionary].flatMap { ($0 as? NSDictionary)?[kCGImagePropertyExifUserComment] })
    }

    func testCorrectsExifOrientation() async throws {
        // A 300x200 image tagged as rotated 90 degrees displays as 200x300; the output bakes that in.
        let input = try ImageFixtures.jpeg(width: 300, height: 200, orientation: .right)
        let output = try await processor.process(input)
        let size = try pixelSize(of: output)
        XCTAssertEqual(size.width, 200)
        XCTAssertEqual(size.height, 300)
        let orientation = try properties(of: output)[kCGImagePropertyOrientation] as? UInt32
        XCTAssertTrue(orientation == nil || orientation == CGImagePropertyOrientation.up.rawValue)
    }

    func testSmallImagesAreNotUpscaled() async throws {
        let output = try await processor.process(try ImageFixtures.png(width: 64, height: 48))
        let size = try pixelSize(of: output)
        XCTAssertEqual(size.width, 64)
        XCTAssertEqual(size.height, 48)
    }

    func testAdversarialContentProcesses() async throws {
        for pattern in [ImageFixtures.Pattern.black, .white, .checkerboard] {
            let output = try await processor.process(try ImageFixtures.png(width: 1200, height: 800, pattern: pattern))
            XCTAssertFalse(output.isEmpty)
            let size = try pixelSize(of: output)
            XCTAssertEqual(size.width, 1200)
            XCTAssertEqual(size.height, 800)
        }
    }

    func testOutputIsHEICOrJPEG() async throws {
        let output = try await processor.process(try ImageFixtures.png(width: 100, height: 100))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(output as CFData, nil))
        let type = try XCTUnwrap(CGImageSourceGetType(source) as String?)
        XCTAssertTrue([UTType.heic.identifier, UTType.jpeg.identifier].contains(type), type)
    }
}
