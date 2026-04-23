//
//  UniversityCatalog.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.04.2026.
//

import Foundation

struct UniversitySeed: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let countryCode: String   // "tr" / "kktc"
}

enum UniversityCatalog {

    static let countries: [(code: String, title: String)] = [
        ("tr", "Türkiye"),
        ("kktc", "KKTC")
    ]

    static let universities: [UniversitySeed] = [
        // KKTC
        UniversitySeed(name: "Akdeniz Karpaz Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Arkın Yaratıcı Sanatlar ve Tasarım Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Atatürk Öğretmen Akademisi", countryCode: "kktc"),
        UniversitySeed(name: "Bahçeşehir Kıbrıs Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Doğu Akdeniz Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Final Uluslararası Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Girne Amerikan Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Girne Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Kıbrıs Amerikan Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Kıbrıs Batı Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Kıbrıs İlim Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Kıbrıs Sağlık ve Toplum Bilimleri Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Kıbrıs Sosyal Bilimler Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Lefke Avrupa Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Near East University", countryCode: "kktc"),
        UniversitySeed(name: "ODTÜ Kuzey Kıbrıs Kampusu", countryCode: "kktc"),
        UniversitySeed(name: "Uluslararası Final Üniversitesi", countryCode: "kktc"),
        UniversitySeed(name: "Uluslararası Kıbrıs Üniversitesi", countryCode: "kktc"),

        // Türkiye
        UniversitySeed(name: "Abdullah Gül Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Acıbadem Mehmet Ali Aydınlar Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Adana Alparslan Türkeş Bilim ve Teknoloji Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Adıyaman Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Afyon Kocatepe Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Ağrı İbrahim Çeçen Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Akdeniz Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Alanya Alaaddin Keykubat Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Altınbaş Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Anadolu Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Ankara Hacı Bayram Veli Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Ankara Medipol Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Ankara Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Ankara Yıldırım Beyazıt Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Antalya Belek Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Atılım Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Bahçeşehir Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Balıkesir Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Bandırma Onyedi Eylül Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Bartın Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Başkent Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Beykent Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Bilecik Şeyh Edebali Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Bingöl Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Biruni Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Boğaziçi Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Bolu Abant İzzet Baysal Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Bursa Teknik Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Bursa Uludağ Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Çağ Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Çanakkale Onsekiz Mart Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Çankaya Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Çukurova Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Demiroğlu Bilim Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Dicle Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Dokuz Eylül Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Düzce Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Ege Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Erciyes Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Erzincan Binali Yıldırım Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Erzurum Teknik Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Eskişehir Osmangazi Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Eskişehir Teknik Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Fatih Sultan Mehmet Vakıf Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Fırat Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Galatasaray Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Gazi Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Gaziantep Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Gebze Teknik Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Hacettepe Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Haliç Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Harran Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Hasan Kalyoncu Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Hitit Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Işık Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İbn Haldun Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İnönü Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İskenderun Teknik Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Arel Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Atlas Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Aydın Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Bilgi Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Esenyurt Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Galata Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Gedik Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Gelişim Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Kent Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Kültür Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Medeniyet Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Medipol Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Okan Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Rumeli Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Sabahattin Zaim Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Teknik Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Ticaret Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Topkapı Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İstanbul Üniversitesi-Cerrahpaşa", countryCode: "tr"),
        UniversitySeed(name: "İstinye Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İzmir Bakırçay Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İzmir Demokrasi Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İzmir Ekonomi Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İzmir Katip Çelebi Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "İzmir Yüksek Teknoloji Enstitüsü", countryCode: "tr"),
        UniversitySeed(name: "Kadir Has Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Karabük Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Karadeniz Teknik Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Kastamonu Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Kayseri Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Kırıkkale Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Kırklareli Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Kocaeli Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Koç Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Konya Teknik Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Maltepe Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Marmara Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "MEF Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Mersin Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Mimar Sinan Güzel Sanatlar Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Munzur Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Necmettin Erbakan Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Niğde Ömer Halisdemir Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Nişantaşı Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Ondokuz Mayıs Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Orta Doğu Teknik Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Özyeğin Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Pamukkale Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Sakarya Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Sakarya Uygulamalı Bilimler Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Selçuk Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "TED Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Tekirdağ Namık Kemal Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "TOBB Ekonomi ve Teknoloji Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Tokat Gaziosmanpaşa Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Toros Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Trabzon Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Trakya Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Türk-Alman Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Ufuk Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Uşak Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Üsküdar Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Yalova Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Yaşar Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Yeditepe Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Yıldız Teknik Üniversitesi", countryCode: "tr"),
        UniversitySeed(name: "Yozgat Bozok Üniversitesi", countryCode: "tr")
    ]

    static func filtered(countryCode: String, query: String) -> [UniversitySeed] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return universities
            .filter { $0.countryCode == countryCode }
            .filter {
                trimmed.isEmpty
                ? true
                : $0.name.localizedCaseInsensitiveContains(trimmed)
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    static func groupedAlphabetically(
        countryCode: String,
        query: String
    ) -> [(key: String, value: [UniversitySeed])] {
        let list = filtered(countryCode: countryCode, query: query)

        let grouped = Dictionary(grouping: list) { item in
            String(item.name.prefix(1)).uppercased()
        }

        return grouped
            .map { ($0.key, $0.value) }
            .sorted { $0.key < $1.key }
    }
}
