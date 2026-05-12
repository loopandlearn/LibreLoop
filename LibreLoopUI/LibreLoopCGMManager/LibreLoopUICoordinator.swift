import Foundation
import UIKit
import SwiftUI
import LoopKit
import LoopKitUI
import LibreLoop

final class LibreLoopUICoordinator: UINavigationController, CGMManagerOnboarding, CompletionNotifying {
    var cgmManagerOnboardingDelegate: CGMManagerOnboardingDelegate?
    var completionDelegate: CompletionDelegate?

    private var cgmManager: LibreLoopCGMManager?
    private let colorPalette: LoopUIColorPalette

    init(cgmManager: LibreLoopCGMManager?, colorPalette: LoopUIColorPalette) {
        self.cgmManager = cgmManager
        self.colorPalette = colorPalette
        super.init(navigationBarClass: UINavigationBar.self, toolbarClass: UIToolbar.self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.prefersLargeTitles = false
        if cgmManager == nil {
            setViewControllers([applySensorViewController()], animated: false)
        } else {
            setViewControllers([settingsViewController()], animated: false)
        }
    }

    // MARK: - Onboarding flow

    private func applySensorViewController() -> UIViewController {
        let view = LibreLoopApplySensorView(
            onNext: { [weak self] in self?.pushScanSensorView() },
            onShowHelp: { [weak self] in self?.presentApplyHelp() },
            onCancel: { [weak self] in self?.cancelOnboarding() }
        )
        return DismissibleHostingController(content: view, colorPalette: colorPalette)
    }

    private func pushScanSensorView() {
        let view = LibreLoopScanSensorView(
            onScan: { [weak self] in self?.startScan() },
            onShowHelp: { [weak self] in self?.presentScanHelp() },
            onShowRecovery: { [weak self] in self?.showRecoveryPlaceholder() },
            onCancel: { [weak self] in self?.cancelOnboarding() }
        )
        let vc = DismissibleHostingController(content: view, colorPalette: colorPalette)
        pushViewController(vc, animated: true)
    }

    private func presentApplyHelp() {
        let view = LibreLoopApplyHelpPagerView(onDone: { [weak self] in
            self?.dismiss(animated: true)
        })
        let host = DismissibleHostingController(content: view, colorPalette: colorPalette)
        present(host, animated: true)
    }

    private func presentScanHelp() {
        let view = LibreLoopScanHelpPagerView(onDone: { [weak self] in
            self?.dismiss(animated: true)
        })
        let host = DismissibleHostingController(content: view, colorPalette: colorPalette)
        present(host, animated: true)
    }

    private func startScan() {
        // TODO: trigger CoreNFC reader session + LibreCRKit PairingFlow.firstPair.
        // For now this just completes onboarding so the rest of the wiring stays exercised.
        completeSetup()
    }

    private func showRecoveryPlaceholder() {
        let alert = UIAlertController(
            title: "Recovery",
            message: "Recovery flow not yet implemented. Tap Start pairing for a fresh sensor.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func cancelOnboarding() {
        completionDelegate?.completionNotifyingDidComplete(self)
    }

    private func completeSetup() {
        let manager = LibreLoopCGMManager()
        self.cgmManager = manager
        cgmManagerOnboardingDelegate?.cgmManagerOnboarding(didCreateCGMManager: manager)
        cgmManagerOnboardingDelegate?.cgmManagerOnboarding(didOnboardCGMManager: manager)
        completionDelegate?.completionNotifyingDidComplete(self)
    }

    // MARK: - Settings

    private func settingsViewController() -> UIViewController {
        let view = LibreLoopSettingsView(
            viewModel: LibreLoopSettingsViewModel(cgmManager: cgmManager!),
            didFinish: { [weak self] in
                guard let self else { return }
                self.completionDelegate?.completionNotifyingDidComplete(self)
            },
            deleteCGM: { [weak self] in
                self?.cgmManager?.notifyDelegateOfDeletion {
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.completionDelegate?.completionNotifyingDidComplete(self)
                        self.dismiss(animated: true)
                    }
                }
            }
        )
        return DismissibleHostingController(content: view, colorPalette: colorPalette)
    }
}
