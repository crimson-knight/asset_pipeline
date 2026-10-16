import XCTest
import SwiftUI
@testable import AssetPipelineSwiftKit

#if canImport(AppKit)
import AppKit

final class SurfaceCraftNoiseRenderingTests: XCTestCase {
    private func pixels(interpolation: String?, usesFace: Bool, frequency: Double = 0.72) throws -> Data {
        _ = NSApplication.shared
        var texture: [String: Any] = [
            "kind": "noise", "opacity": 1.0, "baseFrequency": frequency,
            "octaveCount": 3, "seed": 4, "tileSize": 64
        ]
        if let interpolation { texture["colorInterpolationFilters"] = interpolation }
        let payload = try JSONSerialization.data(withJSONObject: ["texture": texture])
        let spec = try XCTUnwrap(String(data: payload, encoding: .utf8))
        let content: AnyView
        if usesFace {
            content = SurfaceCraftModifiers.face(spec: spec, baseColor: .white, cornerRadius: 0)
        } else {
            content = SurfaceCraftModifiers.apply(
                AnyView(Color.white), spec: spec, keycapStyle: nil,
                cornerRadius: 0, previewState: nil
            )
        }
        let host = NSHostingView(rootView: content.frame(width: 96, height: 96))
        host.frame = NSRect(x: 0, y: 0, width: 96, height: 96)
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let bytes = try XCTUnwrap(bitmap.bitmapData)
        return Data(bytes: bytes, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    }

    func testFaceUsesTheRequestedNoiseColorInterpolation() throws {
        let linear = try pixels(interpolation: "linearRGB", usesFace: true)
        let srgb = try pixels(interpolation: "sRGB", usesFace: true)
        XCTAssertNotEqual(linear, srgb)
    }

    func testAppliedSurfaceUsesTheRequestedNoiseColorInterpolation() throws {
        let linear = try pixels(interpolation: "linearRGB", usesFace: false)
        let srgb = try pixels(interpolation: "sRGB", usesFace: false)
        XCTAssertNotEqual(linear, srgb)
    }

    func testBothSurfacePathsKeepTheDefaultLinearInterpolation() throws {
        for usesFace in [true, false] {
            XCTAssertEqual(
                try pixels(interpolation: nil, usesFace: usesFace),
                try pixels(interpolation: "linearRGB", usesFace: usesFace)
            )
        }
    }

    func testRejectedNoiseParametersLeaveThePlainSurface() throws {
        for usesFace in [true, false] {
            let plain = try pixels(interpolation: "linearRGB", usesFace: usesFace, frequency: 17)
            let valid = try pixels(interpolation: "linearRGB", usesFace: usesFace)
            XCTAssertNotEqual(plain, valid)
            XCTAssertEqual(plain, try pixels(interpolation: "sRGB", usesFace: usesFace, frequency: 17))
        }
    }
}
#endif
