//
//  SettingsViewController.swift
//  ZLoader
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import SwiftUI
#if !os(tvOS)
import MessageUI
#endif
import Intents
#if !os(tvOS)
import IntentsUI
#endif

import SemanticVersion
import SideSign
import UniformTypeIdentifiers

extension SettingsViewController
{
    private enum Section: Int, CaseIterable
    {
        case signIn
        case account
        case patreon
        case display
        case appRefresh
        case instructions
        case techyThings
        case credits
        case betaTesting
        case advancedSettings
        case diagnostics
        case main
        // Keep storyboard identities stable while ordering the visible sections.
        static var allCases: [Section] { [.main, .advancedSettings, .diagnostics, .credits] }
        var displayIndex: Int { Self.allCases.firstIndex(of: self)! }
    }
    
    private enum AppRefreshRow: Int, CaseIterable
    {
        case backgroundRefresh
        case noIdleTimeout        
        case addToSiri
        case disableAppLimit
        
        static var allCases: [AppRefreshRow] {
            var c: [AppRefreshRow] = [.backgroundRefresh, .noIdleTimeout]

            // conditional entries go at the last to preserve ordering
            if UserDefaults.standard.isCowExploitSupported || !ProcessInfo().sparseRestorePatched
            {
                c.append(.disableAppLimit)
            }
            return c
        }
    }
    
    private enum CreditsRow: Int, CaseIterable
    {
        case softwareLicenses
        case developer
        case designer
        case operations
    }
    
    private enum TechyThingsRow: Int, CaseIterable
    {
        case healthCheck
        case errorLog
        case storageExplorer
        case clearCache
        static var allCases: [TechyThingsRow] { [.storageExplorer, .clearCache] }
    }
    private enum AdvancedSettingsRow: Int, CaseIterable
    {
        case sendFeedback           // row 0 - Send Feedback
        case refreshAttempts        // row 1 - View Refresh Attempts
        case refreshSideJITServer   // row 2 - SideJITServer
        case pairingFileManagement  // row 3 - Pairing File Management
        case anisetteServers        // row 4 - Anisette Servers
        case connectionConfig       // row 5 - Connection Configuration
        case networkDiscovery       // row 6 - Network Discovery
        case developerServices      // row 7 - Developer Portal Services
        case profileManagement      // row 8 - Profile Management
        case certificateManagement  // row 9 - Certificate Management
        case backupAndRestore       // row 10 - Backup & Restore
        case signingIdentities
        case userCustomizations
        case containerSettings
        case developerOptions
        case experimentalFeatures
        case shortcuts

        static var allCases: [AdvancedSettingsRow] {
            var rows: [AdvancedSettingsRow] = []
            if UIDevice.current.userInterfaceIdiom != .tv { rows.append(.containerSettings) }
            rows.append(contentsOf: [.developerOptions, .refreshSideJITServer, .pairingFileManagement])
            if !UserDefaults.standard.useOnDeviceAnisette {
                rows.append(.anisetteServers)
            }
            rows.append(contentsOf: [
                .connectionConfig,
                .networkDiscovery,
                .backupAndRestore,
                .shortcuts
            ])
            if UserDefaults.standard.isDebugModeEnabled { rows.append(.experimentalFeatures) }
            return rows
        }
    }

    private enum BetaTestingRow: Int, CaseIterable {
        case betaUpdates
        case betaTrack
    }

    private enum DiagnosticsRow: Int, CaseIterable {
        case healthCheck
        case errorLog
        case refreshAttempts
        case sendFeedback
    }

}

final class SettingsViewController: UITableViewController
{
    private var collapsedSections: Set<Int> = {
        let defaults = UserDefaults.standard
        var sections = Set(defaults.array(forKey: "zLoader.collapsedSettingsSections") as? [Int] ?? [])
        if defaults.integer(forKey: "zLoader.settingsGroupsVersion") < 2 {
            sections.formUnion([Section.advancedSettings.rawValue, Section.diagnostics.rawValue, Section.credits.rawValue])
            defaults.set(2, forKey: "zLoader.settingsGroupsVersion")
        }
        sections.formIntersection([Section.advancedSettings.rawValue, Section.diagnostics.rawValue, Section.credits.rawValue])
        defaults.set(Array(sections).sorted(), forKey: "zLoader.collapsedSettingsSections")
        return sections
    }()
    private var activeTeam: ALTTeam?
    private var accountStatus: AccountVerificationRow.Status = .completed
    private var accountVerificationTask: Task<Void, Never>?
    
    // UIKit may ask for section heights while viewDidLoad is still configuring the table.
    private let prototypeHeaderFooterView = SettingsHeaderFooterView(reuseIdentifier: nil)
    
    // Add outlet
    @IBOutlet private var betaTrackLabel: UILabel!
    @IBOutlet private var betaTrackPopupButton: UIButton!

    private var debugGestureCounter = 0
    private weak var debugGestureTimer: Timer?
    
    @IBOutlet private var accountNameLabel: UILabel!
    @IBOutlet private var accountEmailLabel: UILabel!
    @IBOutlet private var accountTypeLabel: UILabel!
    
    @IBOutlet private var backgroundRefreshSwitch: UISwitch!
    @IBOutlet private var noIdleTimeoutSwitch: UISwitch!
    @IBOutlet private var disableAppLimitSwitch: UISwitch!
    @IBOutlet private var betaUpdatesSwitch: UISwitch!
    @IBOutlet private var verboseOperationsLoggingSwitch: UISwitch!
    @IBOutlet private var altSignVerboseLoggingSwitch: UISwitch!
    @IBOutlet private var minimuxerVerboseLoggingSwitch: UISwitch!
    @IBOutlet private var rotateLogsOnStartupSwitch: UISwitch!
    
//    @IBOutlet private var refreshSideJITServer: UILabel!
    @IBOutlet private var disableResponseCachingSwitch: UISwitch!
    
    
    private let versionLabel = UILabel()
    
    @IBOutlet private var recreateDatabaseSwitch: UISwitch!
    
    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
    #endif
    
    private static var exportDBInProgress = false
    private static var deleteDBInProgress = false
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.openPatreonSettings(_:)), name: AppDelegate.openPatreonSettingsDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.openErrorLog(_:)), name: ToastView.openErrorLogNotification, object: nil)
    }
    
    
    private func handleReleaseChannelSelection(_ channel: String) {
        // Update your model/preferences
        UserDefaults.standard.betaUdpatesTrack = channel
        updateReleaseChannelButtonTitle()
    }
    
    private func updateReleaseChannelButtonTitle() {
        let channel = UserDefaults.standard.betaUdpatesTrack ?? UserDefaults.defaultBetaUpdatesTrack
        betaTrackPopupButton?.setTitle(channel, for: .normal)
    }
    
    private func configureReleaseChannelButton() {
        let currentTrack = UserDefaults.standard.betaUdpatesTrack
        
        // get all tracks as string available except .stable and .unknown
        var trackOptions: [String] = ReleaseTrackType.betaTracks.map {$0.rawValue}

        if let currentTrack{
            // prepend currently selected beta track from the user defaults
            trackOptions = [currentTrack] + trackOptions.filter { $0 != currentTrack }
        }
    
        // Create menu items with proper styling
        let items = trackOptions.map{ channel in
            UIAction(title: channel, handler: { [weak self] _ in
                self?.handleReleaseChannelSelection(channel)
            })
        }
        
        // Create menu with proper styling
        let menu = UIMenu(title: "",
                         options: [.singleSelection, .displayInline], // Add displayInline
                         children: items
        )
        #if !os(tvOS)
        betaTrackPopupButton?.menu = menu
        #else
        if #available(tvOS 17.0, *) {
            betaTrackPopupButton?.menu = menu
        }
        #endif

        // Set initial state
        updateReleaseChannelButtonTitle()
    }


    override func viewDidLoad()
    {
        super.viewDidLoad()
        tableView.register(SettingsHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "HeaderFooterView")
        configureVersionFooter()
        navigationItem.rightBarButtonItem = nil

        
        #if !os(tvOS)
        // --- iOS 26 fix ---
        if #available(iOS 26.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance       // required for iOS 26, maybe enforce it in storyboard?
        }
        #endif 
        let debugModeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(SettingsViewController.handleDebugModeGesture(_:)))
        debugModeGestureRecognizer.delegate = self
        debugModeGestureRecognizer.direction = .up
        #if !os(tvOS)
        debugModeGestureRecognizer.numberOfTouchesRequired = 3
        #endif
        self.tableView.addGestureRecognizer(debugModeGestureRecognizer)
        
        // set the version label to show in settings screen
        self.versionLabel.attributedText = getVersionAttributedString()
        self.versionLabel.isUserInteractionEnabled = true
        self.versionLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyVersionLabelTapped)))
        
        self.versionLabel.numberOfLines = 0
        self.versionLabel.lineBreakMode = .byWordWrapping
        self.versionLabel.setNeedsUpdateConstraints()
        
        self.tableView.contentInset.bottom = 40
        
        self.update()
        
        #if !os(tvOS)
        if let appearance = self.tabBarController?.tabBar.standardAppearance
        {
            appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = .altPrimary
            self.navigationController?.tabBarItem.scrollEdgeAppearance = appearance
        }
        #endif
        
        configureReleaseChannelButton()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        // show nav bar if not shown already
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        
        self.update()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        self.accountVerificationTask?.cancel()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "anisetteServers" || segue.identifier == "developerServices" || segue.identifier == "profileManagement" || segue.identifier == "certificateManagement" || segue.identifier == "diagnostics" {
            let controller = segue.destination
            
        #if !os(tvOS)
            if segue.identifier == "anisetteServers"        || 
                segue.identifier == "developerServices"      ||
                segue.identifier == "profileManagement"      ||
                segue.identifier == "certificateManagement" || 
                segue.identifier == "diagnostics"
            {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithDefaultBackground()
                appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
                appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
                controller.navigationItem.largeTitleDisplayMode = .always
                controller.navigationItem.standardAppearance = appearance
                controller.navigationItem.scrollEdgeAppearance = appearance
            }
        #endif
            
            // disable bottom tab bar since 'back' button is already available
//            controller.hidesBottomBarWhenPushed = true
            
            self.show(controller, sender: nil)
        } else {
            super.prepare(for: segue, sender: sender)
        }
    }

}


private extension SettingsViewController
{
    
    private func configureVersionFooter() {
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 85))
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(versionLabel)
        NSLayoutConstraint.activate([
            versionLabel.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            versionLabel.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16),
            versionLabel.centerYAnchor.constraint(equalTo: footer.centerYAnchor)
        ])
        tableView.tableFooterView = footer
    }

    @objc private func openPairingFiles() {
        // Pairing detail and wireless routes need a SwiftUI navigation container.
        let controller = ZLoaderHostingController(rootView: PairingFileNavigationView(onBack: { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }), usesGlass: false)
        controller.ownsNavigation = true
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }

    private func getVersionAttributedString() -> NSAttributedString {
        let appVersion = Bundle.Info.activeBundleVersion
        let iosVersion = "iOS \(UIDevice.current.systemVersion) (\(ProcessInfo.processInfo.operatingSystemBuild))"
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 4
        
        let fullString = NSMutableAttributedString()
        
        let appVersionAttr = NSAttributedString(
            string: appVersion,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        let iosVersionAttr = NSAttributedString(
            string: "\n" + iosVersion,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.tertiaryLabel,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        fullString.append(appVersionAttr)
        fullString.append(iosVersionAttr)
        return fullString
    }
    
    @objc private func copyVersionLabelTapped() {
        let appVersion = Bundle.Info.activeBundleVersion
        let iosVersion = "iOS \(UIDevice.current.systemVersion) (\(ProcessInfo.processInfo.operatingSystemBuild))"
        let fullText = "\(appVersion)\n\(iosVersion)"
        #if !os(tvOS)
        UIPasteboard.general.string = fullText.hasPrefix("Version ") ? String(fullText.dropFirst("Version ".count)) : fullText
        #endif
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributed = NSMutableAttributedString(
            string: "Copied! ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraphStyle
            ]
        )
        attributed.append(NSAttributedString(string: "✓", attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.systemGreen
        ]))
        self.versionLabel.attributedText = attributed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.versionLabel.attributedText = self?.getVersionAttributedString()
        }
    }
    
    
    func update()
    {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let currentActiveTeam = try? await AuthManager.shared.getAuthenticatedTeam()
            let appleID = AuthManager.shared.currentAppleID
            verboseLog("[SettingsVC] update() called. activeTeam: \(currentActiveTeam?.identifier ?? "nil"), account: \(appleID ?? "nil")")
            
            if let team = currentActiveTeam, AuthManager.shared.isAuthenticated
            {
                self.accountNameLabel?.text = team.name
                self.accountEmailLabel?.text = appleID
                self.accountTypeLabel?.text = team.type.localizedDescription
                
                self.activeTeam = team
                self.startAccountVerification(for: team)
            }
            else
            {
                self.activeTeam = nil
                self.accountVerificationTask?.cancel()
                self.accountVerificationTask = nil
                self.accountStatus = .completed
                self.updateAccountCardRowStyles()
            }
            self.configureSignOutButton()
            self.tableView.reloadData()
        }

        // AppRefreshRow
        self.backgroundRefreshSwitch?.isOn = UserDefaults.standard.isBackgroundRefreshEnabled
        self.noIdleTimeoutSwitch?.isOn = UserDefaults.standard.isIdleTimeoutDisableEnabled
        self.disableAppLimitSwitch?.isOn = UserDefaults.standard.isAppLimitDisabled

        // BetaTestingRow
        self.betaUpdatesSwitch?.isOn = UserDefaults.standard.isBetaUpdatesEnabled
        self.betaTrackPopupButton?.isEnabled = UserDefaults.standard.isBetaUpdatesEnabled

        // DiagnosticsRow
        // DiagnosticsRow (managed via DeveloperOptionsView)
        self.disableResponseCachingSwitch?.isOn = UserDefaults.standard.responseCachingDisabled
        self.verboseOperationsLoggingSwitch?.isOn = UserDefaults.standard.isVerboseOperationsLoggingEnabled
        self.altSignVerboseLoggingSwitch?.isOn = UserDefaults.standard.isAltSignVerboseLoggingEnabled
        self.minimuxerVerboseLoggingSwitch?.isOn = UserDefaults.standard.isMinimuxerVerboseLoggingEnabled
        self.rotateLogsOnStartupSwitch?.isOn = UserDefaults.standard.isRotateLogsOnStartupEnabled
        self.recreateDatabaseSwitch?.isOn = UserDefaults.standard.recreateDatabaseOnNextStart

        if self.isViewLoaded
        {
            self.tableView.reloadData()
        }
    }
    
    private func configureSignOutButton() {
        guard activeTeam != nil else {
            navigationItem.rightBarButtonItem = nil
            return
        }
        let item = UIBarButtonItem(title: NSLocalizedString("Sign Out", comment: ""), style: .plain, target: self, action: #selector(signOut(_:)))
        item.tintColor = .systemRed
        item.accessibilityIdentifier = "settings-sign-out"
        navigationItem.rightBarButtonItem = item
    }

    private func startAccountVerification(for team: ALTTeam)
    {
        self.accountVerificationTask?.cancel()
        self.accountVerificationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            if !UserDefaults.standard.isDeviceRegistered {
                self.accountStatus = .checking
                self.tableView.reloadData()
                self.updateAccountCardRowStyles()
            }
            let status = await AccountVerificationRow.verifyStatus(for: team)
            if !Task.isCancelled {
                self.accountStatus = status
                self.tableView.reloadData()
                self.updateAccountCardRowStyles()
            }
        }
    }
    
    private func updateAccountCardRowStyles() { /* Native list configuration owns row grouping. */ }

    private func resolvePendingAccountActions()
    {
        guard let team = self.activeTeam else { return }
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await AccountVerificationRow.resolvePendingActions(for: self.accountStatus, team: team, presentingViewController: self)
            self.startAccountVerification(for: team)
        }
    }
    
    private func prepare(_ settingsHeaderFooterView: SettingsHeaderFooterView, for section: Section, isHeader: Bool)
    {
        settingsHeaderFooterView.resetDisclosure()
        settingsHeaderFooterView.primaryLabel.isHidden = !isHeader
        settingsHeaderFooterView.secondaryLabel.isHidden = isHeader
        settingsHeaderFooterView.button.isHidden = true
        
        settingsHeaderFooterView.configureMargins(isHeader: isHeader)
        
        switch section
        {
        case .main: break
        case .signIn:
            if isHeader
            {
                settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("ACCOUNT", comment: "")
            }
            else
            {
                settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString("Sign in with your Apple ID to download apps from zLoader.", comment: "")
            }
            
        case .patreon:
            if isHeader
            {
                settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("SUPPORT US", comment: "")
            }
            else
            {
                settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString("Support the zLoader Team by following our socials or becoming a patron!", comment: "")
            }

        case .account:
            settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("ACCOUNT", comment: "")
            
        case .appRefresh:
            if isHeader
            {
                settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("REFRESHING APPS", comment: "")
            }
            else
            {
                settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString("Enable Background Refresh to automatically refresh apps in the background when connected to Wi-Fi. \n\nEnable Disable Idle Timeout to allow zLoader to keep your device awake during a refresh or install of any apps.", comment: "")
            }
            
        case .display:
            if isHeader
            {
                settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("DISPLAY", comment: "")
            }
            else
            {
                settingsHeaderFooterView.secondaryLabel.text = String(localized: "Choose the appearance, language and app icon.", table: "SettingsLayout")
            }
            
            
        case .instructions:
            break
            
        case .techyThings:
            if isHeader
            {
                settingsHeaderFooterView.primaryLabel.text = String(localized: "Storage", table: "SettingsLayout")
            }
            else
            {
                settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString("Free up disk space by removing non-essential data, such as temporary files and backups for uninstalled apps.", comment: "")
            }
            
        case .credits:
            settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("CREDITS", comment: "")
            
        case .advancedSettings:
            settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("ADVANCED SETTINGS", comment: "")

        case .betaTesting:
            if isHeader
            {
                settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("BETA TESTING", comment: "")
            }
            else
            {
                settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString(
                    """
                    Opt in for beta testing to receive regular updates and early previews of upcoming releases.\n
                    Please note that these builds are experimental and may be unstable or break unexpectedly.
                    """,
                    comment: ""
                )
            }
            

            
        case .diagnostics:
            settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("DIAGNOSTICS", comment: "")
            
        // case .macDirtyCow:
        //     if isHeader
        //     {
        //         settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("MACDIRTYCOW", comment: "")
        //     }
        //     else
        //     {
        //         settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString("If you've removed the 3-sideloaded app limit via the MacDirtyCow exploit, disable this setting to sideload more than 3 apps at a time.", comment: "")
        //     }
            
        }
    }
    
    private func preferredHeight(for settingsHeaderFooterView: SettingsHeaderFooterView, in section: Section, isHeader: Bool) -> CGFloat
    {
        let availableWidth = tableView.layoutMarginsGuide.layoutFrame.width
        let widthConstraint = settingsHeaderFooterView.contentView.widthAnchor.constraint(equalToConstant: availableWidth > 0 ? availableWidth : tableView.bounds.width)
        NSLayoutConstraint.activate([widthConstraint])
        defer { NSLayoutConstraint.deactivate([widthConstraint]) }
        
        self.prepare(settingsHeaderFooterView, for: section, isHeader: isHeader)
        if isHeader && section != .main {
            settingsHeaderFooterView.configureDisclosure(identifier: "", collapsed: collapsedSections.contains(section.rawValue), action: {})
        }

        let size = settingsHeaderFooterView.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return size.height
    }
    
    private func isSectionHidden(_ section: Section) -> Bool
    {
        switch section
        {
        case .patreon, .betaTesting: return true
        // case .macDirtyCow:
        //     let isHidden = !(UserDefaults.standard.isCowExploitSupported && UserDefaults.standard.isDebugModeEnabled)
        //     return isHidden
            
        default: return false
        }
    }
}

private extension SettingsViewController
{
    func signIn()
    {
        debugLog("[SettingsVC] signIn() invoked by user action")
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let result = try await AuthManager.shared.signIn(presentingViewController: self)
                debugLog("[SettingsVC] signIn() authentication succeeded for team: \(result.team.name) (\(result.team.identifier))")
            } catch is CancellationError {
                debugLog("[SettingsVC] signIn() authentication cancelled by user")
            } catch {
                debugLog("[SettingsVC] signIn() authentication failed with error: \(error)")
                let toastView = ToastView(error: error)
                toastView.show(in: self.view)
            }
            
            debugLog("[SettingsVC] signIn() calling update()...")
            self.update()
        }
    }
    
    @objc func signOut(_ sender: UIBarButtonItem)
    {
        debugLog("[SettingsVC] signOut() invoked by user action")
        let contentVC = SignOutAlertViewController()
        
        let alertController = UIAlertController(
            title: NSLocalizedString("Sign Out", comment: ""),
            message: NSLocalizedString("Are you sure you want to sign out? You will no longer be able to install or refresh apps once you sign out.", comment: ""),
            preferredStyle: .alert
        )
        
        alertController.setValue(contentVC, forKey: "contentViewController")
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
        
        let signOutAction = UIAlertAction(title: NSLocalizedString("Sign Out", comment: ""), style: .destructive) { [weak self] _ in
            let keepCert = contentVC.isChecked
            let keepAnisette = contentVC.isKeepAnisetteChecked
            let keepAnisetteHeaders = contentVC.isKeepAnisetteHeadersChecked
            let keepSideSignHeaders = contentVC.isKeepSideSignHeadersChecked
            Task { @MainActor [weak self] in
                await AuthManager.shared.signOut(
                    keepCertificate: keepCert,
                    keepAnisetteData: keepAnisette,
                    keepAnisetteHeaders: keepAnisetteHeaders,
                    keepSideSignHeaders: keepSideSignHeaders
                )
                await MainActor.run {
                    self?.update()
                }
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(signOutAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func toggleDisableAppLimit(_ sender: UISwitch) {
        if UserDefaults.standard.isCowExploitSupported || !ProcessInfo().sparseRestorePatched {
            // accept state change only when valid
            UserDefaults.standard.isAppLimitDisabled = sender.isOn
            
            // TODO: Here we force reload the activeAppsLimit after detecting change in isAppLimitDisabled
            //       Why do we need to do this, once identified if this is intentional and working as expected, remove this todo
            if UserDefaults.standard.activeAppsLimit != nil
            {
                UserDefaults.standard.activeAppsLimit = InstalledApp.freeAccountActiveAppsLimit
            }
        }
    }
    
    @IBAction func toggleVerboseOperationsLogging(_ sender: UISwitch) {
        // update it in database
        UserDefaults.standard.isVerboseOperationsLoggingEnabled = sender.isOn
    }

    @IBAction func toggleAltSignVerboseLogging(_ sender: UISwitch) {
        // update it in database
        UserDefaults.standard.isAltSignVerboseLoggingEnabled = sender.isOn
        AltSign.setLogging(sender.isOn)
    }

    @IBAction func toggleMinimuxerVerboseLogging(_ sender: UISwitch) {
        // update it in database
        UserDefaults.standard.isMinimuxerVerboseLoggingEnabled = sender.isOn
        minimuxerSetLogging(sender.isOn)
    }

    @IBAction func toggleRotateLogsOnStartup(_ sender: UISwitch) {
        UserDefaults.standard.isRotateLogsOnStartupEnabled = sender.isOn
        let suffixFormat: SuffixFormat = sender.isOn ? .timestamp : .none
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.consoleLog.updateConfiguration(baseName: "console", suffixFormat: suffixFormat, policy: .immediate)
    }

    @IBAction func toggleRecreateDatabaseSwitch(_ sender: UISwitch) {
        // Update the setting in UserDefaults
        UserDefaults.standard.recreateDatabaseOnNextStart = sender.isOn

        guard sender.isOn else { return }
        
        DispatchQueue.global().async {
            for time in (1...3).reversed() {
                DispatchQueue.main.async {
                    guard UserDefaults.standard.recreateDatabaseOnNextStart else {
                        return
                    }
                    let toast = ToastView(text: "Database Delete Scheduled on Next Launch", detailText: "App is closing in \(time) seconds...")
                    toast.tintColor = .altPrimary
                    toast.preferredDuration = 1
                    toast.show(in: self)
                }
                sleep(1) // Background sleep
            }

            DispatchQueue.main.async {
                guard UserDefaults.standard.recreateDatabaseOnNextStart else {
                    return
                }
                exit(0)
            }
        }
    }

    
    @IBAction func toggleEnableBetaUpdates(_ sender: UISwitch) {
        betaTrackLabel.isEnabled = sender.isOn
        betaTrackPopupButton?.isEnabled = sender.isOn
        // update it in database
        UserDefaults.standard.isBetaUpdatesEnabled = sender.isOn
    }
    
    @IBAction func toggleIsBackgroundRefreshEnabled(_ sender: UISwitch)
    {
        UserDefaults.standard.isBackgroundRefreshEnabled = sender.isOn
    }
    
    @IBAction func toggleNoIdleTimeoutEnabled(_ sender: UISwitch)
    {
        UserDefaults.standard.isIdleTimeoutDisableEnabled = sender.isOn
    }
    
    @IBAction func toggleDisableResponseCaching(_ sender: UISwitch)
    {
        UserDefaults.standard.responseCachingDisabled = sender.isOn
    }
    
    #if !os(tvOS)
    func addRefreshAppsShortcut()
    {
        guard let shortcut = INShortcut(intent: INInteraction.refreshAllApps().intent) else { return }
        
        let viewController = INUIAddVoiceShortcutViewController(shortcut: shortcut)
        viewController.delegate = self
        viewController.modalPresentationStyle = .formSheet
        self.present(viewController, animated: true, completion: nil)
    }
    #endif
    
    func clearCache()
    {
        let makeCacheTitle: (String) -> String = { sizeString in
            String(format: NSLocalizedString("Are you sure you want to clear zLoader's cache?\n\nCache Size: %@", comment: ""), sizeString)
        }
        let alertController = UIAlertController(title: makeCacheTitle(NSLocalizedString("Calculating…", comment: "")),
                                                message: NSLocalizedString("This will remove all temporary files as well as backups for uninstalled apps.", comment: ""),
                                                preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: UIAlertAction.cancel.title, style: UIAlertAction.cancel.style) { [weak self] _ in
            self?.tableView.indexPathForSelectedRow.map { self?.tableView.deselectRow(at: $0, animated: true) }
        })
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Clear Cache", comment: ""), style: .destructive) { [weak self] _ in
            AppManager.shared.clearAppCache { result in
                DispatchQueue.main.async {
                    self?.tableView.indexPathForSelectedRow.map { self?.tableView.deselectRow(at: $0, animated: true) }
                    
                    switch result
                    {
                    case .success: break
                    case .failure(let error):
                        let alertController = UIAlertController(title: NSLocalizedString("Unable to Clear Cache", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
                        alertController.addAction(.ok)
                        self?.present(alertController, animated: true)
                    }
                }
            }
        })
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }
        
        self.present(alertController, animated: true)
        
        // Update title once the actual cache size is computed in background
        CacheManager.shared.formattedCacheSize { [weak alertController] sizeString in
            DispatchQueue.main.async {
                alertController?.title = makeCacheTitle(sizeString)
            }
        }
    }
    
    @IBAction func handleDebugModeGesture(_ gestureRecognizer: UISwipeGestureRecognizer)
    {
        self.debugGestureCounter += 1
        self.debugGestureTimer?.invalidate()
        
        if self.debugGestureCounter >= 3
        {
            self.debugGestureCounter = 0
            
            UserDefaults.standard.isDebugModeEnabled.toggle()
            self.tableView.reloadData()
        }
        else
        {
            self.debugGestureTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] (timer) in
                self?.debugGestureCounter = 0
            }
        }
    }
    
    func openTwitter(username: String)
    {
        let twitterAppURL = URL(string: "twitter://user?screen_name=" + username)!
        UIApplication.shared.open(twitterAppURL, options: [:]) { (success) in
            if success
            {
                if let selectedIndexPath = self.tableView.indexPathForSelectedRow
                {
                    self.tableView.deselectRow(at: selectedIndexPath, animated: true)
                }
            }
            else
            {
                let safariURL = URL(string: "https://twitter.com/" + username)!
                self.openWebURL(safariURL, preferredTintColor: .altPrimary)
            }
        }
    }
    
    func openMastodon(username: String)
    {
        // Rely on universal links to open app.
        
        let components = username.split(separator: "@")
        guard components.count == 2 else { return }
        
        let server = String(components[1])
        let username = "@" + String(components[0])
        
        guard let serverURL = URL(string: "https://" + server) else { return }
        
        let mastodonURL = serverURL.appendingPathComponent(username)
        UIApplication.shared.open(mastodonURL, options: [:])
    }
    
    func openThreads(username: String)
    {
        // Rely on universal links to open app.
        
        let safariURL = URL(string: "https://www.threads.net/@" + username)!
        UIApplication.shared.open(safariURL, options: [:])
    }
    
    @objc func openPatreonSettings(_ notification: Notification)
    {
        guard self.presentedViewController == nil else { return }
                
        UIView.performWithoutAnimation {
            self.navigationController?.popViewController(animated: false)
            self.performSegue(withIdentifier: "showPatreon", sender: nil)
        }
    }

    @objc func openErrorLog(_: Notification) {
        guard self.presentedViewController == nil else { return }

        self.navigationController?.popViewController(animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.performSegue(withIdentifier: "showErrorLog", sender: nil)
        }
    }
}

extension SettingsViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        // Container and user settings remain available when diagnostics are hidden.
        return Section.allCases.count
    }
    
    private func storyboardIndexPath(for indexPath: IndexPath) -> IndexPath {
        let section = Section.allCases[indexPath.section]
        var row = indexPath.row
        switch section {
        case .advancedSettings:
            let item = AdvancedSettingsRow.allCases[row]
            if item == .developerOptions || item == .experimentalFeatures {
                return IndexPath(row: item == .developerOptions ? 0 : 1, section: Section.diagnostics.rawValue)
            }
            row = item.rawValue
        case .diagnostics:
            switch DiagnosticsRow.allCases[row] {
            case .healthCheck: return IndexPath(row: 0, section: Section.techyThings.rawValue)
            case .errorLog: return IndexPath(row: 1, section: Section.techyThings.rawValue)
            case .refreshAttempts: return IndexPath(row: 1, section: Section.advancedSettings.rawValue)
            case .sendFeedback: return IndexPath(row: 0, section: Section.advancedSettings.rawValue)
            }
        case .techyThings: row = TechyThingsRow.allCases[row].rawValue
        case .appRefresh: row = AppRefreshRow.allCases[row].rawValue
        default: break
        }
        return IndexPath(row: row, section: section.rawValue)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        if let insetCell = cell as? InsetGroupTableViewCell {
            let count = tableView.numberOfRows(inSection: indexPath.section)
            insetCell.style = count == 1 ? .single : indexPath.row == 0 ? .top : indexPath.row == count - 1 ? .bottom : .middle
        }
        if Section.allCases[indexPath.section] == .account {
            if indexPath.row == 2, let insetCell = cell as? InsetGroupTableViewCell {
                insetCell.style = .middle
            } else if indexPath.row == 5, let actionCell = cell as? AccountVerificationRow {
                actionCell.style = .bottom
                actionCell.backgroundColor = .clear
                actionCell.contentView.backgroundColor = .clear
                actionCell.backgroundConfiguration = .clear()
            }
        }
    }

    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int { 0 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section) || collapsedSections.contains(section.rawValue): return 0
        case .main: return mainRows.count
        case .signIn: return (self.activeTeam == nil) ? 2 : 0
        case .account: return (self.activeTeam == nil) ? 0 : (self.accountStatus == .completed ? 5 : 6)
        case .display: return 2
        case .appRefresh: return AppRefreshRow.allCases.count
        case .techyThings: return TechyThingsRow.allCases.count
        case .advancedSettings: return AdvancedSettingsRow.allCases.count
        case .diagnostics: return DiagnosticsRow.allCases.count
        default: return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        if Section.allCases[indexPath.section] == .main { return mainCell(for: mainRows[indexPath.row]) }
        if Section.allCases[indexPath.section] == .signIn && indexPath.row == 1 {
            return settingsNavigationCell(title: NSLocalizedString("Certificates", comment: ""), identifier: "settings-signing-identities")
        }
        if Section.allCases[indexPath.section] == .display && indexPath.row == 1 {
            return settingsNavigationCell(title: NSLocalizedString("Appearance", comment: ""), identifier: "settings-appearance")
        }
        if Section.allCases[indexPath.section] == .advancedSettings {
            switch AdvancedSettingsRow.allCases[indexPath.row] {
            case .userCustomizations: return settingsNavigationCell(title: NSLocalizedString("User Customizations", comment: ""), identifier: "settings-user-customizations")
            case .containerSettings: return settingsNavigationCell(title: String(localized: "Container Settings", table: "SettingsLayout"), identifier: "settings-container")
            case .shortcuts: return settingsNavigationCell(title: NSLocalizedString("Shortcuts", comment: ""), identifier: "settings-shortcuts")
            default: break
            }
        }
        if Section.allCases[indexPath.section] == .credits {
            if indexPath.row == 0 {
                let cell = super.tableView(tableView, cellForRowAt: IndexPath(row: 3, section: Section.credits.rawValue))
                (cell as? InsetGroupTableViewCell)?.style = .top
                decorateSettingsCell(cell)
                return cell
            }
            let cell = InsetGroupTableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.style = indexPath.row == 3 ? .bottom : .middle
            cell.isSelectable = true
            let titles = ["About zynthec-dev", "Main Repository", "Based on SideStore"]
            let details = [ZLoaderBrand.maintainer, "zynthec-dev/zLoader-ios", "SideStore, AltStore and their contributors"]
            cell.textLabel?.text = NSLocalizedString(titles[indexPath.row - 1], comment: "")
            cell.detailTextLabel?.text = details[indexPath.row - 1]
            cell.textLabel?.font = .preferredFont(forTextStyle: .body)
            cell.textLabel?.textColor = .label
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.backgroundColor = .clear
            cell.accessoryType = .disclosureIndicator
            decorateSettingsCell(cell)
            return cell
        }

        if Section.allCases[indexPath.section] == .account && indexPath.row == 3 {
            let cell = InsetGroupTableViewCell(style: .default, reuseIdentifier: nil)
            cell.style = .middle
            cell.isSelectable = true
            cell.accessibilityIdentifier = "settings-signing-identities"
            cell.textLabel?.text = NSLocalizedString("Certificates", comment: "")
            cell.accessoryType = .disclosureIndicator
            decorateSettingsCell(cell)
            return cell
        }
        if Section.allCases[indexPath.section] == .account && indexPath.row == 4 {
            let cell = InsetGroupTableViewCell(style: .default, reuseIdentifier: nil)
            cell.style = accountStatus == .completed ? .bottom : .middle
            let paid = self.activeTeam?.type.isPaid == true
            cell.isSelectable = paid
            cell.textLabel?.text = NSLocalizedString("Apple Developer Portal", comment: "")
            cell.accessoryType = .disclosureIndicator
            cell.textLabel?.textColor = paid ? .label : .tertiaryLabel
            decorateSettingsCell(cell)
            cell.imageView?.tintColor = paid ? .settingsSymbol : .tertiaryLabel
            return cell
        }
        if Section.allCases[indexPath.section] == .account && indexPath.row == 5 {
            let cell = tableView.dequeueReusableCell(withIdentifier: AccountVerificationRow.reuseIdentifier) as? AccountVerificationRow
                ?? AccountVerificationRow()
            cell.configure(with: self.accountStatus)
            cell.style = .bottom
            decorateSettingsCell(cell)
            return cell
        }
        
        let cell = super.tableView(tableView, cellForRowAt: storyboardIndexPath(for: indexPath))
        if Section.allCases[indexPath.section] == .signIn { cell.accessibilityIdentifier = "settings-sign-in" }
        if Section.allCases[indexPath.section] == .advancedSettings {
            let row = AdvancedSettingsRow.allCases[indexPath.row]
            if row == .developerOptions { cell.accessibilityIdentifier = "settings-developer-options" }
            if row == .experimentalFeatures { cell.accessibilityIdentifier = "settings-experimental-features" }
        }
        if Section.allCases[indexPath.section] == .diagnostics {
            cell.accessibilityIdentifier = "settings-diagnostics-\(DiagnosticsRow.allCases[indexPath.row])"
        }
        if Section.allCases[indexPath.section] == .account {
            if indexPath.row == 2 {
                if let insetCell = cell as? InsetGroupTableViewCell {
                    insetCell.style = .middle
                }
            }
        }
        

        if AppRefreshRow.AllCases().count == 1
        {
            if let cell = cell as? InsetGroupTableViewCell,
               Section.allCases[indexPath.section] == .appRefresh,
               indexPath.row == AppRefreshRow.backgroundRefresh.rawValue
            {
                cell.style = .single
            }
        }
        
        if let cell = cell as? InsetGroupTableViewCell,
               Section.allCases[indexPath.section] == .appRefresh,
               indexPath.row == AppRefreshRow.allCases.count - 1  // last row
        {
            cell.style = .bottom
        }
        
        
        decorateSettingsCell(cell)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection index: Int) -> UIView? {
        let section = Section.allCases[index]
        guard section != .main else { return nil }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderFooterView") as? SettingsHeaderFooterView ?? SettingsHeaderFooterView(reuseIdentifier: "HeaderFooterView")
        prepare(header, for: section, isHeader: true)
        header.configureDisclosure(identifier: "settings-section-\(section)", collapsed: collapsedSections.contains(section.rawValue)) { [weak self] in
            guard let self else { return }
            if self.collapsedSections.contains(section.rawValue) { self.collapsedSections.remove(section.rawValue) }
            else { self.collapsedSections.insert(section.rawValue) }
            UserDefaults.standard.set(Array(self.collapsedSections).sorted(), forKey: "zLoader.collapsedSettingsSections")
            self.tableView.reloadSections(IndexSet(integer: section.displayIndex), with: UIAccessibility.isReduceMotionEnabled ? .none : .automatic)
        }
        return header
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection index: Int) -> CGFloat {
        let section = Section.allCases[index]
        return section == .main ? .leastNormalMagnitude : preferredHeight(for: prototypeHeaderFooterView, in: section, isHeader: true)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { nil }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { nil }
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { nil }
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { .leastNormalMagnitude }

}

extension SettingsViewController
{
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let section = Section.allCases[indexPath.section]
        verboseLog("[SettingsVC] didSelectRowAt: section \(section) (index \(indexPath.section)), row \(indexPath.row)")
        switch section
        {
        case .main: selectMain(mainRows[indexPath.row])
        case .signIn:
            if indexPath.row == 1 { navigationController?.pushSigningView(CertificatesView(presentingViewController: self)) }
            else { self.signIn() }
        case .account:
            tableView.deselectRow(at: indexPath, animated: true)
            if indexPath.row == 3 {
                navigationController?.pushSigningView(CertificatesView(presentingViewController: self))
            } else if indexPath.row == 4, self.activeTeam?.type.isPaid == true {
                navigationController?.pushViewController(ZLoaderHostingController(rootView: DeveloperServicesView(presentingViewController: self), usesGlass: false), animated: true)
            } else if indexPath.row == 5 {
                self.resolvePendingAccountActions()
            }
        case .appRefresh:
            let row = AppRefreshRow.allCases[indexPath.row]
            switch row
            {
            case .backgroundRefresh: break
            case .noIdleTimeout: break
            case .disableAppLimit: break
            case .addToSiri:
//                guard #available(iOS 14, *) else { return }   // our min deployment is iOS 15 now :) so commented out
                #if !os(tvOS)
                self.addRefreshAppsShortcut()
                #endif
            }
            
        case .techyThings:
            if indexPath.row == TechyThingsRow.allCases.count {
                navigationController?.pushViewController(ZLoaderHostingController(rootView: ShortcutsSettingsView(), usesGlass: false), animated: true)
                return
            }
            let row = TechyThingsRow.allCases[indexPath.row]
            switch row
            {
            case .healthCheck:
                let healthCheckView = HealthCheckView()
                let vc = ZLoaderHostingController(rootView: healthCheckView, usesGlass: false)
                
                #if !os(tvOS)
                let appearance = UINavigationBarAppearance()
                appearance.configureWithDefaultBackground()
                vc.navigationItem.scrollEdgeAppearance = appearance
                vc.navigationItem.standardAppearance = appearance
                #endif
                
                navigationController?.pushViewController(vc, animated: true)
                
            case .errorLog: break
            case .storageExplorer:
                verboseLog("[SettingsVC] Storage Explorer selected")
                StorageExplorerView.clearCache()
                func makeExplorerVC(url: URL? = nil) -> UIViewController {
                    let onSelectFolder: (URL) -> Void = { [weak self] targetURL in
                        guard let self = self else { return }
                        verboseLog("[SettingsVC] Navigating to child folder: \(targetURL.path)")
                        let childVC = makeExplorerVC(url: targetURL)
                        self.navigationController?.pushViewController(childVC, animated: true)
                    }
                    if let url = url {
                        verboseLog("[SettingsVC] Creating DirectoryExplorerView for: \(url.path)")
                        let view = DirectoryExplorerView(url: url, onSelectFolder: onSelectFolder)
                        return ZLoaderHostingController(rootView: view, usesGlass: false)
                    } else {
                        verboseLog("[SettingsVC] Creating root StorageExplorerView")
                        let view = StorageExplorerView(onSelectFolder: onSelectFolder)
                        return ZLoaderHostingController(rootView: view, usesGlass: false)
                    }
                }
                let vc = makeExplorerVC()
                verboseLog("[SettingsVC] Pushing root StorageExplorerView controller onto navigationController")
                navigationController?.pushViewController(vc, animated: true)
                
            case .clearCache: self.clearCache()
            }
            
        case .credits:
            let row = CreditsRow.allCases[indexPath.row]
            switch row
            {
            case .developer: navigationController?.pushViewController(ZLoaderHostingController(rootView: ZLoaderAboutView(), usesGlass: false), animated: true)
            case .operations: self.openWebURL(ZLoaderBrand.upstreamURL, preferredTintColor: .altPrimary)
            case .designer: self.openWebURL(ZLoaderBrand.repositoryURL, preferredTintColor: .altPrimary)
            case .softwareLicenses: break
            }
            
            if let selectedIndexPath = self.tableView.indexPathForSelectedRow
            {
                self.tableView.deselectRow(at: selectedIndexPath, animated: true)
            }
            
        case .advancedSettings:
            let row = AdvancedSettingsRow.allCases[indexPath.row]
            switch row
            {
            case .userCustomizations: pushSettings(UserCustomizationsView(), title: NSLocalizedString("User Customizations", comment: ""))
            case .containerSettings: navigationController?.pushViewController(ContainerSettingsViewController(), animated: true)
            case .developerOptions: pushSettings(DeveloperOptionsView(), title: NSLocalizedString("Developer Options", comment: ""))
            case .experimentalFeatures: pushSettings(ExperimentalFeaturesView(), title: NSLocalizedString("Experimental Features", comment: ""))
            case .shortcuts: pushSettings(ShortcutsSettingsView(), title: NSLocalizedString("Shortcuts", comment: ""))
            case .signingIdentities:
                navigationController?.pushSigningView(CertificatesView(presentingViewController: self))
            case .sendFeedback:
                let alertController = UIAlertController(title: "Send Feedback", message: "Choose a method to send feedback:", preferredStyle: .actionSheet)
                
                // Option 1: GitHub
                alertController.addAction(UIAlertAction(title: "GitHub", style: .default) { _ in
                    self.openWebURL(ZLoaderBrand.repositoryURL, preferredTintColor: .altPrimary)
                })
                
                // Cancel action
                alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                
                // For iPad: Set the source view if presenting on iPad to avoid crashes
                if let popoverController = alertController.popoverPresentationController {
                    popoverController.sourceView = self.view
                    popoverController.sourceRect = self.view.bounds
                }
                
                // Present the action sheet
                self.present(alertController, animated: true, completion: nil)
                
            case .refreshSideJITServer:
                let jitConfigView = SideJITServerConfigView()
                let vc = ZLoaderHostingController(rootView: jitConfigView, usesGlass: false)
                #if !os(tvOS)
                let appearance = UINavigationBarAppearance()
                appearance.configureWithDefaultBackground()
                vc.navigationItem.scrollEdgeAppearance = appearance
                vc.navigationItem.standardAppearance = appearance
                #endif
                self.navigationController?.pushViewController(vc, animated: true)
                self.tableView.deselectRow(at: indexPath, animated: true)
                
            case .pairingFileManagement:
                openPairingFiles()
                self.tableView.deselectRow(at: indexPath, animated: true)

            case .anisetteServers:
                let anisetteServersView = AnisetteServersView(
                    selected: UserDefaults.standard.menuAnisetteURL,
                    onResetAdiPb: { [weak self] in
                        guard let self = self else { return }
                        ToastView(text: "Cleared adi.pb!", detailText: "You will need to log back into Apple ID in zLoader.")
                            .show(in: self)
                    }
                )
                
                let vc = ZLoaderHostingController(rootView: anisetteServersView, usesGlass: false)
                self.prepare(for: UIStoryboardSegue(identifier: "anisetteServers", source: self, destination: vc), sender: nil)

            case .connectionConfig:
                let connectionConfigView = ConnectionConfigView()
                let vc = ZLoaderHostingController(rootView: connectionConfigView, usesGlass: false)

                #if !os(tvOS)
                let appearance = UINavigationBarAppearance()
                appearance.configureWithDefaultBackground()   // gives solid background
                vc.navigationItem.scrollEdgeAppearance = appearance
                vc.navigationItem.standardAppearance = appearance
                #endif

                navigationController?.pushViewController(vc, animated: true)

            case .networkDiscovery:
                let discoveryView = BonjourDiscoveryView()
                let vc = ZLoaderHostingController(rootView: discoveryView, usesGlass: false)
                vc.view.backgroundColor = .settingsBackground
                vc.title = NSLocalizedString("Network Discovery", comment: "")
                self.prepare(for: UIStoryboardSegue(identifier: "diagnostics", source: self, destination: vc), sender: nil)

            case .developerServices:
                let developerServicesView = DeveloperServicesView(presentingViewController: self)
                let vc = ZLoaderHostingController(rootView: developerServicesView, usesGlass: false)
                self.prepare(for: UIStoryboardSegue(identifier: "developerServices", source: self, destination: vc), sender: nil)

            case .profileManagement:
                let profileManagementView = ProfileManagementView(presentingViewController: self)
                let vc = ZLoaderHostingController(rootView: profileManagementView, usesGlass: false)
                self.prepare(for: UIStoryboardSegue(identifier: "profileManagement", source: self, destination: vc), sender: nil)

            case .certificateManagement:
                let certificateManagementView = CertificatesView(presentingViewController: self)
                let vc = ZLoaderHostingController(rootView: certificateManagementView, usesGlass: false)
                self.prepare(for: UIStoryboardSegue(identifier: "certificateManagement", source: self, destination: vc), sender: nil)
                
            case .backupAndRestore:
                let backupView = BackupAndRestoreView()
                let vc = ZLoaderHostingController(rootView: backupView, usesGlass: false)
                vc.view.backgroundColor = .settingsBackground
                vc.title = NSLocalizedString("Backup & Restore", comment: "")
                self.prepare(for: UIStoryboardSegue(identifier: "diagnostics", source: self, destination: vc), sender: nil)
                
            case .refreshAttempts: break
            }
        
        case .diagnostics:
            switch DiagnosticsRow.allCases[indexPath.row] {
            case .healthCheck: pushSettings(HealthCheckView(), title: NSLocalizedString("Health Check", comment: ""))
            case .errorLog, .refreshAttempts: break // Original storyboard destinations remain connected.
            case .sendFeedback:
                self.openWebURL(ZLoaderBrand.repositoryURL, preferredTintColor: .altPrimary)
            }
        case .display:
            if indexPath.row == 1 { pushSettings(ThemePickerView(), title: NSLocalizedString("Appearance", comment: "")) }

        // case .account, .patreon, .display, .instructions, .macDirtyCow: break
        case .patreon, .instructions, .betaTesting: break
        }
        
        
        // deselect the row before returning (so that it doesn't look like stuck selected)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

#if !os(tvOS)
extension SettingsViewController: MFMailComposeViewControllerDelegate
{
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
    {
        if let error = error
        {
            let toastView = ToastView(error: error)
            toastView.show(in: self)
        }
        
        controller.dismiss(animated: true, completion: nil)
    }
}
#endif

extension SettingsViewController: UIGestureRecognizerDelegate
{
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    {
        return true
    }
}

#if !os(tvOS)
extension SettingsViewController: INUIAddVoiceShortcutViewControllerDelegate
{
    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?)
    {
        if let indexPath = self.tableView.indexPathForSelectedRow
        {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        
        controller.dismiss(animated: true, completion: nil)
        
        guard let error = error else { return }
        
        let toastView = ToastView(error: error)
        toastView.show(in: self)
    }
    
    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController)
    {
        if let indexPath = self.tableView.indexPathForSelectedRow
        {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        
        controller.dismiss(animated: true, completion: nil)
    }
}
#endif

extension SettingsViewController {
    private enum MainRow: Equatable {
        case customizations, signIn, accountName, accountEmail, accountType, certificates, portal, verification
        case appearance, backgroundRefresh, idleTimeout, disableLimit, storage, clearCache, help
    }

    private var mainRows: [MainRow] {
        var rows: [MainRow] = [.customizations]
        if activeTeam == nil { rows.append(.signIn) }
        else { rows.append(contentsOf: [.accountName, .accountEmail, .accountType]) }
        rows.append(.certificates)
        if activeTeam != nil {
            rows.append(.portal)
            if accountStatus != .completed { rows.append(.verification) }
        }
        rows.append(contentsOf: [.appearance, .backgroundRefresh, .idleTimeout])
        if AppRefreshRow.allCases.contains(.disableAppLimit) { rows.append(.disableLimit) }
        rows.append(contentsOf: [.storage, .clearCache, .help])
        return rows
    }

    private func mainCell(for row: MainRow) -> UITableViewCell {
        switch row {
        case .customizations: return settingsNavigationCell(title: NSLocalizedString("User Customizations", comment: ""), identifier: "settings-user-customizations")
        case .certificates: return settingsNavigationCell(title: NSLocalizedString("Certificates", comment: ""), identifier: "settings-signing-identities")
        case .appearance: return settingsNavigationCell(title: NSLocalizedString("Appearance", comment: ""), identifier: "settings-appearance")
        case .portal:
            let cell = settingsNavigationCell(title: NSLocalizedString("Apple Developer Portal", comment: ""), identifier: "settings-apple-portal")
            cell.isUserInteractionEnabled = activeTeam?.type.isPaid == true
            return cell
        case .verification:
            let cell = AccountVerificationRow()
            cell.configure(with: accountStatus)
            return cell
        default: break
        }
        let source: IndexPath
        switch row {
        case .signIn: source = IndexPath(row: 0, section: Section.signIn.rawValue)
        case .accountName: source = IndexPath(row: 0, section: Section.account.rawValue)
        case .accountEmail: source = IndexPath(row: 1, section: Section.account.rawValue)
        case .accountType: source = IndexPath(row: 2, section: Section.account.rawValue)
        case .backgroundRefresh: source = IndexPath(row: 0, section: Section.appRefresh.rawValue)
        case .idleTimeout: source = IndexPath(row: 1, section: Section.appRefresh.rawValue)
        case .disableLimit: source = IndexPath(row: 3, section: Section.appRefresh.rawValue)
        case .storage: source = IndexPath(row: 2, section: Section.techyThings.rawValue)
        case .clearCache: source = IndexPath(row: 3, section: Section.techyThings.rawValue)
        case .help: source = IndexPath(row: 0, section: Section.instructions.rawValue)
        default: preconditionFailure("Synthetic settings row must be configured above")
        }
        let cell = super.tableView(tableView, cellForRowAt: source)
        if row == .signIn { cell.accessibilityIdentifier = "settings-sign-in" }
        decorateSettingsCell(cell)
        return cell
    }

    private func selectMain(_ row: MainRow) {
        switch row {
        case .customizations: pushSettings(UserCustomizationsView(), title: NSLocalizedString("User Customizations", comment: ""))
        case .signIn: signIn()
        case .certificates: navigationController?.pushSigningView(CertificatesView(presentingViewController: self))
        case .portal:
            if activeTeam?.type.isPaid == true { pushSettings(DeveloperServicesView(presentingViewController: self), title: NSLocalizedString("Apple Developer Portal", comment: "")) }
        case .verification: resolvePendingAccountActions()
        case .appearance:
            pushSettings(ThemePickerView(onAppIcon: { [weak self] in
                guard let self, let controller = self.storyboard?.instantiateViewController(withIdentifier: "appIconSettings") else { return }
                self.navigationController?.pushViewController(controller, animated: true)
            }), title: NSLocalizedString("Appearance", comment: ""))
        case .storage:
                verboseLog("[SettingsVC] Storage Explorer selected")
                StorageExplorerView.clearCache()
                func makeExplorerVC(url: URL? = nil) -> UIViewController {
                    let onSelectFolder: (URL) -> Void = { [weak self] targetURL in
                        guard let self = self else { return }
                        verboseLog("[SettingsVC] Navigating to child folder: \(targetURL.path)")
                        let childVC = makeExplorerVC(url: targetURL)
                        self.navigationController?.pushViewController(childVC, animated: true)
                    }
                    if let url = url {
                        verboseLog("[SettingsVC] Creating DirectoryExplorerView for: \(url.path)")
                        let view = DirectoryExplorerView(url: url, onSelectFolder: onSelectFolder)
                        return ZLoaderHostingController(rootView: view, usesGlass: false)
                    } else {
                        verboseLog("[SettingsVC] Creating root StorageExplorerView")
                        let view = StorageExplorerView(onSelectFolder: onSelectFolder)
                        return ZLoaderHostingController(rootView: view, usesGlass: false)
                    }
                }
                let vc = makeExplorerVC()
                verboseLog("[SettingsVC] Pushing root StorageExplorerView controller onto navigationController")
                navigationController?.pushViewController(vc, animated: true)

        case .clearCache: clearCache()
        default: break
        }
    }

    private func pushSettings<Content: View>(_ view: Content, title: String) {
        let controller = ZLoaderHostingController(rootView: view, usesGlass: false)
        controller.title = title
        navigationController?.pushViewController(controller, animated: true)
    }

    private func settingsNavigationCell(title: String, identifier: String) -> UITableViewCell {
        let cell = InsetGroupTableViewCell(style: .default, reuseIdentifier: nil)
        cell.isSelectable = true
        cell.textLabel?.text = title
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = identifier
        decorateSettingsCell(cell)
        return cell
    }

    private func decorateSettingsCell(_ cell: UITableViewCell) {
        cell.backgroundConfiguration = .listCell()
        guard let cell = cell as? InsetGroupTableViewCell, !(cell is AccountVerificationRow) else { return }
        cell.configureNativeContent()
    }
}
