//
//  AppGuideManager.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.03.2026.
//

import SwiftUI
import Combine

enum AppGuideScreen: String {
    case home
    case tasks
    case week
    case done
}

enum AppGuideStep: Int, CaseIterable {
    case homeWelcome
    case homeProgress
    case homeFocusPrompt
    case homeFocusStarted
    case homeTasksPrompt
    case tasksIntro
    case tasksWorkoutPrompt
    case weekPrompt
    case weekIntro
    case weekCompletedIntro
    case done

    var screen: AppGuideScreen {
        switch self {
        case .homeWelcome, .homeProgress, .homeFocusPrompt, .homeFocusStarted, .homeTasksPrompt:
            return .home
        case .tasksIntro, .tasksWorkoutPrompt:
            return .tasks
        case .weekPrompt, .weekIntro, .weekCompletedIntro:
            return .week
        case .done:
            return .done
        }
    }

    var title: String {
        switch self {
        case .homeWelcome:
            return "Burası ana ekranın"
        case .homeProgress:
            return "İlerlemeni burada görürsün"
        case .homeFocusPrompt:
            return "Şimdi focus kartına bas"
        case .homeFocusStarted:
            return "Focus aktifken kart değişir"
        case .homeTasksPrompt:
            return "Şimdi task ekranını açalım"
        case .tasksIntro:
            return "Burası görev ekranın"
        case .tasksWorkoutPrompt:
            return "Buradan workout veya normal task seçebilirsin"
        case .weekPrompt:
            return "Şimdi week ekranına geçelim"
        case .weekIntro:
            return "Burası haftalık planın"
        case .weekCompletedIntro:
            return "Tamamlanan event'ler burada görünür"
        case .done:
            return "Hazırsın"
        }
    }

    var message: String {
        switch self {
        case .homeWelcome:
            return "Günlük özetin, önemli kartların ve hızlı erişimlerin burada yer alır."
        case .homeProgress:
            return "Bugünkü ilerlemeni, serini ve motivasyon durumunu burada takip edebilirsin."
        case .homeFocusPrompt:
            return "Focus kartına dokun. Aktif olunca görünüm ve durum rengi değişecek."
        case .homeFocusStarted:
            return "Bak, focus aktifken kart canlı görünür ve geri sayım başlar."
        case .homeTasksPrompt:
            return "Şimdi görev ekranını açıp neler ekleyebileceğini görelim."
        case .tasksIntro:
            return "Task ekranında görev oluşturur, düzenler ve türüne göre yönetirsin."
        case .tasksWorkoutPrompt:
            return "Workout seçersen set odaklı ilerlersin, normal task seçersen klasik görev gibi çalışır."
        case .weekPrompt:
            return "Week ekranında planını günlere göre görür ve takip edersin."
        case .weekIntro:
            return "Burada event'lerini, schedule'ını ve gün düzenini yönetirsin."
        case .weekCompletedIntro:
            return "Bitirdiğin event'ler completed alanına düşer ve gün içindeki akışın net görünür."
        case .done:
            return "Artık uygulamanın temel akışını biliyorsun."
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .homeWelcome, .homeProgress, .homeFocusStarted, .tasksIntro, .weekIntro, .weekCompletedIntro:
            return "Next"
        case .homeFocusPrompt:
            return "Focus'a Bas"
        case .homeTasksPrompt:
            return "Tasks'i Aç"
        case .tasksWorkoutPrompt:
            return "Week'e Git"
        case .weekPrompt:
            return "Open Week"
        case .done:
            return "Finish"
        }
    }

    var requiresUserAction: Bool {
        switch self {
        case .homeFocusPrompt, .homeTasksPrompt, .tasksWorkoutPrompt, .weekPrompt:
            return true
        default:
            return false
        }
    }
}

final class AppGuideManager: ObservableObject {
    @AppStorage("didFinishAppGuide") private var didFinishAppGuide = false

    @Published var isActive: Bool = false
    @Published var currentStep: AppGuideStep = .homeWelcome

    func startIfNeeded() {
        guard !didFinishAppGuide else { return }
        guard !isActive else { return }
        isActive = true
        currentStep = .homeWelcome
    }

    func forceStart() {
        didFinishAppGuide = false
        isActive = true
        currentStep = .homeWelcome
    }

    func next() {
        guard let next = AppGuideStep(rawValue: currentStep.rawValue + 1) else {
            finish()
            return
        }

        if next == .done {
            finish()
        } else {
            currentStep = next
        }
    }

    func back() {
        guard currentStep.rawValue > 0,
              let previous = AppGuideStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    func finish() {
        didFinishAppGuide = true
        isActive = false
    }

    var currentScreen: AppGuideScreen {
        currentStep.screen
    }

    var progressText: String {
        let visibleSteps = AppGuideStep.allCases.filter { $0 != .done }
        let index = visibleSteps.firstIndex(of: currentStep) ?? 0
        return "\(index + 1)/\(visibleSteps.count)"
    }

    // MARK: Home highlights

    var highlightsHomeHeader: Bool {
        currentStep == .homeWelcome
    }

    var highlightsHomeProgress: Bool {
        currentStep == .homeProgress
    }

    var highlightsHomeFocus: Bool {
        currentStep == .homeFocusPrompt || currentStep == .homeFocusStarted
    }

    var highlightsHomeTasksShortcut: Bool {
        currentStep == .homeTasksPrompt
    }

    // MARK: Tasks highlights

    var highlightsTasksScreen: Bool {
        currentStep == .tasksIntro
    }

    var highlightsTaskTypeArea: Bool {
        currentStep == .tasksWorkoutPrompt
    }

    // MARK: Week highlights

    var highlightsWeekScreen: Bool {
        currentStep == .weekIntro
    }

    var highlightsWeekCompleted: Bool {
        currentStep == .weekCompletedIntro
    }
}
