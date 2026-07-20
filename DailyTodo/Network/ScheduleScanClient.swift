//
//  ScheduleScanClient.swift
//  DailyTodo
//
//  Fotoğraftan ders programı: 1-4 fotoğrafı küçültüp backend'in görü
//  endpoint'ine yollar (/v1/ai/schedule-scan), yapılandırılmış ders+slot
//  listesi döner. Günde 3 tarama; maliyet aylık AI bütçesinden düşer.
//

import Foundation
import UIKit
import Supabase

struct ScannedScheduleSlot: Decodable, Hashable {
    let weekday: Int          // 0=Pzt … 6=Paz (EventItem ile aynı)
    let startMinute: Int
    let durationMinute: Int
    /// Derslik ("CL 110", "CLA 24" …) — takvim event'inin location'ı olur.
    let room: String?
}

struct ScannedScheduleCourse: Decodable, Identifiable, Hashable {
    let name: String
    let code: String
    let slots: [ScannedScheduleSlot]

    var id: String { "\(code)|\(name)" }
}

enum ScheduleScanError: LocalizedError {
    case dailyLimit
    case budget
    case server

    var errorDescription: String? {
        switch self {
        case .dailyLimit: return tr("css_scan_err_limit")
        case .budget: return tr("ai_monthly_limit")
        case .server: return tr("css_scan_err_generic")
        }
    }
}

enum ScheduleScanClient {

    static func scan(_ images: [UIImage]) async throws -> [ScannedScheduleCourse] {
        // Uzun dikey ekran görüntüleri tek parça küçültülünce metin okunamaz
        // hale geliyor (genişlik ~250px'e iner) — önce dilimle, sonra küçült.
        let prepared = images.prefix(4)
            .flatMap { $0.scanSlices() }
            .prefix(8)

        let payload = prepared.compactMap { image -> String? in
            image.scanResized(maxDimension: 1600)
                .jpegData(compressionQuality: 0.65)?
                .base64EncodedString()
        }

        guard !payload.isEmpty else { throw ScheduleScanError.server }

        let session = try await SupabaseManager.shared.client.auth.session
        guard let url = URL(string: "\(ChatBackendEnvironment.httpBaseURL)/v1/ai/schedule-scan") else {
            throw ScheduleScanError.server
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["images": payload])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        if status == 429 { throw ScheduleScanError.dailyLimit }
        if status == 402 { throw ScheduleScanError.budget }
        guard status == 200 else { throw ScheduleScanError.server }

        struct ScanResponse: Decodable {
            let ok: Bool
            let courses: [ScannedScheduleCourse]
        }

        let decoded = try JSONDecoder().decode(ScanResponse.self, from: data)
        guard decoded.ok else { throw ScheduleScanError.server }
        return decoded.courses
    }
}

private extension UIImage {
    /// Görü modeline yeterli, upload'ı hafif tutan küçültme.
    func scanResized(maxDimension: CGFloat) -> UIImage {
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return self }

        let scale = maxDimension / largest
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Boyu eninin 2.2 katından uzun görüntüleri (uzun portal ekran
    /// görüntüleri) dikeyde 2-4 bindirmeli dilime böler — her dilim tam
    /// çözünürlükte kalır, satırlar kesilmesin diye %6 bindirme bırakılır.
    func scanSlices() -> [UIImage] {
        guard let cg = cgImage else { return [self] }

        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        guard height > width * 2.2 else { return [self] }

        let sliceCount = min(4, max(2, Int(ceil(height / (width * 1.5)))))
        let overlap = height * 0.06 / CGFloat(sliceCount)
        let sliceHeight = height / CGFloat(sliceCount)

        var slices: [UIImage] = []
        for index in 0..<sliceCount {
            let top = max(0, sliceHeight * CGFloat(index) - overlap)
            let bottom = min(height, sliceHeight * CGFloat(index + 1) + overlap)
            let rect = CGRect(x: 0, y: top, width: width, height: bottom - top)

            if let cropped = cg.cropping(to: rect) {
                slices.append(UIImage(cgImage: cropped, scale: 1, orientation: imageOrientation))
            }
        }

        return slices.isEmpty ? [self] : slices
    }
}
