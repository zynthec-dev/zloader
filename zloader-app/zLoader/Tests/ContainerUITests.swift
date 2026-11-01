import XCTest

final class ContainerUITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.zynthec.zLoader")

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        let denyNotifications = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons
            .matching(NSPredicate(format: "label IN %@", ["Nicht erlauben", "Don’t Allow", "Don't Allow"])).firstMatch
        if denyNotifications.waitForExistence(timeout: 2) { denyNotifications.tap() }
    }

    func test001OnboardingAndContainerPages() throws {
        for _ in 0..<8 {
            if app.tabBars.buttons["Meine Apps"].exists { break }
            let labels = ["Open zLoader", "zLoader öffnen", "Continue Without Apple Account", "Ohne Apple-Account fortfahren",
                          "Ohne Apple-Konto fortfahren", "Set Up Later", "Später einrichten", "Get Started", "Los geht’s", "Los geht's", "Continue", "Weiter"]
            guard let button = labels.map({ app.buttons[$0] }).first(where: { $0.exists && $0.isHittable && $0.isEnabled }) else {
                // Startup now correctly keeps inert tabs out of accessibility
                // until the fade is finished. An onboarded app has no action.
                if app.tabBars.buttons["Meine Apps"].waitForExistence(timeout: 15) { break }
                attach("onboarding-blocked")
                print("Visible buttons: " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
                print(app.debugDescription)
                XCTFail("Onboarding has no expected navigation action")
                return
            }
            button.tap()
        }
        XCTAssertTrue(app.tabBars.buttons["Meine Apps"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Meine Apps"].tap()
        let pages = app.segmentedControls["my-apps-pages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 10))
        attach("installed-app-grid")
        pages.buttons["Apps in Containern"].tap()
        XCTAssertTrue(app.buttons["Container sortieren"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label IN %@", ["Install App", "App installieren"])).count, 1)
        attach("container-page")
        pages.buttons["Installierte Apps"].tap()
        XCTAssertFalse(app.buttons["discover-ipa-library"].exists)
        app.swipeLeft()
        XCTAssertTrue(pages.buttons["Apps in Containern"].isSelected)
        app.swipeRight()
        XCTAssertTrue(pages.buttons["Installierte Apps"].isSelected)
        app.tabBars.buttons["Entdecken"].tap()
        XCTAssertTrue(app.buttons["discover-ipa-library"].waitForExistence(timeout: 5))
        app.buttons["discover-ipa-library"].tap()
        attach("discover-ipa-library")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Einstellungen"].tap()
        let container = app.staticTexts["Container-Einstellungen"].firstMatch
        for _ in 0..<8 where !container.isHittable { app.swipeUp() }
        XCTAssertTrue(container.waitForExistence(timeout: 5))
        container.tap()
        XCTAssertFalse(app.buttons["Identität übernehmen"].exists)
        XCTAssertFalse(app.buttons["Container-Quellen"].exists)
        XCTAssertTrue(app.buttons["container-jitless-diagnostics"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: "Container-Einstellungen").count, 1)
        XCTAssertLessThan(app.navigationBars["Container-Einstellungen"].frame.height, 60)
        attach("container-settings-simplified")
        let identity = app.buttons["container-device-identity-settings"]
        XCTAssertTrue(identity.waitForExistence(timeout: 10))
        identity.tap()
        XCTAssertTrue(app.buttons["container-regenerate-device-identity"].waitForExistence(timeout: 10))
        attach("container-device-identity")
    }

    func test002IPAChoiceAndContainerImport() throws {
        app.tabBars.buttons["Meine Apps"].tap()
        for name in ["Alpha", "Beta", "Legacy"] {
            let pages = app.segmentedControls["my-apps-pages"]
            XCTAssertTrue(pages.waitForExistence(timeout: 15))
            pages.buttons["Apps in Containern"].tap()
            if app.otherElements["container-app-info-de.zloader.acceptance." + name.lowercased()].exists { continue }
            let install = app.buttons.matching(NSPredicate(format: "label IN %@", ["Install App", "App installieren"])).firstMatch
            XCTAssertTrue(install.waitForExistence(timeout: 10))
            install.tap()
            let files = app.buttons.matching(NSPredicate(format: "label IN %@", ["Choose from Files", "Aus Dateien wählen"])).firstMatch
            if files.waitForExistence(timeout: 3) { files.tap() }
            let browse = app.buttons.matching(NSPredicate(format: "label IN %@", ["Browse", "Durchsuchen"])).firstMatch
            if browse.waitForExistence(timeout: 3) { browse.tap() }
            let local = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["On My iPhone", "Auf meinem iPhone"])).firstMatch
            if local.waitForExistence(timeout: 3) { local.tap() }
            let folder = app.staticTexts["zLoader"].firstMatch
            if folder.waitForExistence(timeout: 3) { folder.tap() }
            let file = app.staticTexts.matching(NSPredicate(format: "label IN %@", [name, name + ".ipa"])).firstMatch
            guard file.waitForExistence(timeout: 8) else {
                attach("ipa-picker"); print(app.debugDescription); XCTFail("Fixture IPA not visible"); return
            }
            let fileCell = app.cells.matching(NSPredicate(format: "identifier == %@", name + ".ipa, ipa")).firstMatch
            if fileCell.exists {
                fileCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
            } else { file.tap() }
            let device = app.buttons["install-destination-device"]
            let container = app.buttons["install-destination-container"]
            XCTAssertTrue(device.waitForExistence(timeout: 10))
            XCTAssertTrue(container.exists)
            XCTAssertTrue(device.isEnabled)
            XCTAssertLessThan(app.navigationBars["Installation wählen"].frame.minY, app.frame.height * 0.1)
            attach("ipa-destination-" + name)
            container.tap()
            let info = app.otherElements["container-app-info-de.zloader.acceptance." + name.lowercased()]
            XCTAssertTrue(info.waitForExistence(timeout: 20))
            XCTAssertTrue(app.segmentedControls["my-apps-pages"].buttons["Apps in Containern"].isSelected)
        }
        attach("two-container-apps")
    }

    func test003VirtualIdentityAndInternalBrowserCallbacks() throws {
        let sharedID = selectIdentity(virtual: true)
        launchContainer("alpha")
        XCTAssertEqual(app.staticTexts["fixture-title"].label, "Alpha")
        XCTAssertEqual(app.staticTexts["fixture-idfv"].label, sharedID)
        XCTAssertEqual(app.staticTexts["fixture-product-type"].label, "iPhone17,2")
        XCTAssertEqual(app.staticTexts["fixture-uname"].label, "iPhone17,2")
        for browser in ["WK", "Safari", "ASSession", "ASCallback", "Wrapper"] {
            app.buttons["fixture-login-" + browser].tap()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let allow = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Continue", "Fortfahren"])).firstMatch
            if allow.waitForExistence(timeout: 2) { allow.tap() }
            let finish = app.links["Finish fixture login"].firstMatch
            XCTAssertTrue(finish.waitForExistence(timeout: 15))
            finish.tap()
            let callback = app.staticTexts["fixture-callback"]
            expectation(for: NSPredicate(format: "label CONTAINS %@", "state=acceptance"), evaluatedWith: callback)
            waitForExpectations(timeout: 15)
            XCTAssertTrue(callback.label.contains("code=synthetic"))
            XCTAssertEqual(XCUIApplication(bundleIdentifier: "de.zloader.acceptance.nativecollision").state, .notRunning)
            attach("internal-callback-" + browser)
        }
        app.terminate(); app.launch()
        launchContainer("beta")
        XCTAssertEqual(app.staticTexts["fixture-title"].label, "Beta")
        XCTAssertEqual(app.staticTexts["fixture-idfv"].label, sharedID)
        app.terminate(); app.launch()
        _ = selectIdentity(virtual: true)
        app.buttons["container-regenerate-device-identity"].tap()
        app.buttons["Neu erstellen"].tap()
        let newID = app.staticTexts["container-shared-idfv"].label
        XCTAssertNotEqual(newID, sharedID)
        app.terminate(); app.launch()
        launchContainer("alpha")
        XCTAssertEqual(app.staticTexts["fixture-idfv"].label, newID)
        XCTAssertGreaterThan(Int(app.staticTexts["fixture-launch-count"].label) ?? 0, 1)
        app.terminate(); app.launch()
        _ = selectIdentity(virtual: false)
        app.terminate(); app.launch()
        launchContainer("alpha")
        XCTAssertNotEqual(app.staticTexts["fixture-idfv"].label, newID)
        XCTAssertNotEqual(app.staticTexts["fixture-product-type"].label, "iPhone17,2")
        attach("container-host-identity")
    }

    func test004HomeScreenShortcutActions() throws {
        app.tabBars.buttons["Meine Apps"].tap()
        let pages = app.segmentedControls["my-apps-pages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 15))
        pages.buttons["Apps in Containern"].tap()
        let info = app.otherElements["container-app-info-de.zloader.acceptance.alpha"]
        XCTAssertTrue(info.waitForExistence(timeout: 10))
        info.press(forDuration: 1)
        app.buttons["Zum Home-Bildschirm hinzufügen"].tap()
        app.buttons["Start-URL kopieren"].tap()
        // The harness verifies this synthetic URL with simctl pbpaste. iOS
        // correctly denies another app (the XCTest runner) direct clipboard access.
        info.press(forDuration: 1)
        app.buttons["Zum Home-Bildschirm hinzufügen"].tap()
        app.buttons["Verknüpfung erstellen"].tap()
        app.buttons["Hell"].tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.links["Profil laden"].waitForExistence(timeout: 15))
        let close = app.buttons.matching(NSPredicate(format: "label IN %@", ["Schließen", "Fertig", "Done", "Abbrechen"])).firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts["Fehler"].exists)
        attach("home-screen-shortcut-configuration")
        close.tap()
    }

    func test005SharedPlusAndURLField() throws {
        app.tabBars.buttons["Meine Apps"].tap()
        let pages = app.segmentedControls["my-apps-pages"]
        pages.buttons["Apps in Containern"].tap()
        let plus = app.buttons.matching(NSPredicate(format: "label IN %@", ["Install App", "App installieren"])).firstMatch
        plus.tap()
        app.buttons.matching(NSPredicate(format: "label IN %@", ["Install from URL", "Von URL installieren"])).firstMatch.tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("https://example.com/app.ipa")
        XCTAssertEqual(field.value as? String, "https://example.com/app.ipa")
        attach("rounded-url-input")
        app.alerts.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "Abbrechen"])).firstMatch.tap()
        XCTAssertTrue(pages.buttons["Apps in Containern"].isSelected)
    }

    func test007LegacyWrappedBrowserCallback() throws {
        launchContainer("legacy")
        XCTAssertEqual(app.staticTexts["fixture-title"].label, "Legacy")
        app.buttons["fixture-login-Wrapper"].tap()
        let finish = app.links["Finish fixture login"].firstMatch
        XCTAssertTrue(finish.waitForExistence(timeout: 15))
        finish.tap()
        let callback = app.staticTexts["fixture-callback"]
        expectation(for: NSPredicate(format: "label CONTAINS %@", "state=acceptance"), evaluatedWith: callback)
        waitForExpectations(timeout: 15)
        XCTAssertTrue(callback.label.contains("code=synthetic"))
        XCTAssertEqual(XCUIApplication(bundleIdentifier: "de.zloader.acceptance.nativecollision").state, .notRunning)
        attach("legacy-wrapper-callback")
    }

    func test006VirtualMultitasking() throws {
        app.tabBars.buttons["Meine Apps"].tap()
        let pages = app.segmentedControls["my-apps-pages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 15))
        pages.buttons["Apps in Containern"].tap()
        let info = app.otherElements["container-app-info-de.zloader.acceptance.alpha"]
        XCTAssertTrue(info.waitForExistence(timeout: 10))
        info.press(forDuration: 1)
        app.buttons["Multitasking"].tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.staticTexts["fixture-title"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["fixture-title"].label, "Alpha")
        app.buttons["Container-Fenstergröße ändern"].firstMatch.tap()
        app.buttons["Container-Fenstergröße ändern"].firstMatch.tap()
        app.buttons["Container minimieren"].firstMatch.tap()
        let beta = app.otherElements["container-app-info-de.zloader.acceptance.beta"]
        XCTAssertTrue(beta.waitForExistence(timeout: 10))
        beta.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Mit JIT starten"].exists)
        app.buttons["Multitasking"].tap()
        let betaTitle = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "fixture-title", "Beta")).firstMatch
        XCTAssertTrue(betaTitle.waitForExistence(timeout: 20))
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        attach("container-virtual-multitasking-two-guests")
        app.buttons["Container schließen"].firstMatch.tap()
    }

    func test008SettingsOrderAndSingleBackNavigation() throws {
        // Exercise settings on an onboarded app independently of device pairing.
        app.terminate()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-zLoader.collapsedSettingsSections", "()"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        // The unfolded simulator exposes the vertical tab strip as buttons,
        // while an ordinary phone exposes the same actions inside a TabBar.
        let settings = app.buttons["Einstellungen"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 20))
        settings.tap()
        let developer = app.cells["settings-developer-options"]
        let container = app.cells["settings-container"]
        let customizations = app.cells["settings-user-customizations"]
        for _ in 0..<10 where !customizations.isHittable { app.swipeUp() }
        attach("settings084-menu-before-check")
        print("Settings rows: developer=\(developer.exists)/\(developer.isHittable), container=\(container.exists)/\(container.isHittable), custom=\(customizations.exists)/\(customizations.isHittable)")
        if !container.exists || !customizations.exists { print(app.debugDescription) }
        XCTAssertTrue(developer.exists && container.isHittable && customizations.exists)
        XCTAssertEqual(app.cells.matching(identifier: "settings-container").count, 1)
        XCTAssertEqual(app.cells.matching(identifier: "settings-user-customizations").count, 1)
        XCTAssertLessThan(customizations.frame.midY, container.frame.midY)
        XCTAssertLessThan(container.frame.midY, developer.frame.midY)
        attach("settings084-menu-order")

        container.tap()
        XCTAssertTrue(app.buttons["container-settings-back"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.navigationBars.count, 1)
        XCTAssertEqual(app.navigationBars.buttons.count, 1)
        XCTAssertFalse(app.staticTexts["Mehrere LiveContainer"].exists)
        XCTAssertFalse(app.staticTexts["Multiple LiveContainers"].exists)
        attach("settings084-container-root")

        app.buttons["container-device-identity-settings"].tap()
        XCTAssertTrue(app.buttons["container-regenerate-device-identity"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.navigationBars.count, 1)
        XCTAssertEqual(app.navigationBars.buttons.count, 1)
        XCTAssertFalse(app.buttons["container-settings-back"].exists)
        attach("settings084-identity-single-back")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["container-settings-back"].waitForExistence(timeout: 5))

        app.buttons["container-jitless-diagnostics"].tap()
        XCTAssertEqual(app.navigationBars.count, 1)
        XCTAssertEqual(app.navigationBars.buttons.count, 1)
        attach("settings084-diagnostics-single-back")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["container-settings-back"].tap()
        XCTAssertTrue(container.waitForExistence(timeout: 5))
        XCTAssertEqual(app.navigationBars.count, 1)
        customizations.tap()
        XCTAssertEqual(app.navigationBars.count, 1)
        XCTAssertEqual(app.navigationBars.buttons.count, 1)
        XCTAssertFalse(app.buttons["Appearance"].exists)
        XCTAssertFalse(app.buttons["Darstellung"].exists)
        attach("settings087-user-customizations")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(container.waitForExistence(timeout: 5))
    }

    func test012CollapsibleSettingsAndAppearance() throws {
        app.terminate()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-zLoader.collapsedSettingsSections", "()", "-zLoader.appearance", "light"]
        app.launch()
        app.buttons["Einstellungen"].firstMatch.tap()
        let appearance = app.cells["settings-appearance"]
        for _ in 0..<8 where !appearance.isHittable { app.swipeUp() }
        XCTAssertTrue(appearance.isHittable)
        appearance.tap()
        XCTAssertTrue(app.buttons["appearance-mode"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["Accent Color"].exists)
        attach("settings087-native-appearance")
        app.buttons["appearance-mode"].tap()
        app.buttons["Dunkel"].tap()
        attach("settings087-native-appearance-dark")
        app.buttons["appearance-mode"].tap()
        app.buttons["Automatisch"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        let display = app.buttons["settings-section-display"]
        display.tap()
        XCTAssertFalse(appearance.exists)
        attach("settings087-display-collapsed")
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE", "-hasCompletedOnboarding", "YES"]
        app.launch()
        app.buttons["Einstellungen"].firstMatch.tap()
        XCTAssertTrue(display.waitForExistence(timeout: 10))
        XCTAssertEqual(display.value as? String, "Eingeklappt")
        XCTAssertFalse(appearance.exists)
        display.tap()
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        let advanced = app.buttons["settings-section-advancedSettings"]
        for _ in 0..<10 where !advanced.isHittable { app.swipeUp() }
        XCTAssertTrue(advanced.isHittable)
        advanced.tap()
        XCTAssertFalse(app.cells["settings-user-customizations"].exists)
        let health = app.cells["settings-diagnostics-healthCheck"]
        for _ in 0..<8 where !health.isHittable { app.swipeUp() }
        XCTAssertTrue(health.isHittable)
        attach("settings087-diagnostics-and-credits")
        health.tap()
        XCTAssertFalse(app.cells["settings-developer-options"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        let credits = app.buttons["settings-section-credits"]
        for _ in 0..<8 where !credits.isHittable { app.swipeUp() }
        XCTAssertTrue(credits.isHittable)
        let diagnostics = app.buttons["settings-section-diagnostics"]
        XCTAssertLessThan(diagnostics.frame.midY, credits.frame.midY)
        attach("settings087-credits-last")
        // Restore all groups so the following tests have independent state.
        for _ in 0..<10 where !advanced.isHittable { app.swipeDown() }
        advanced.tap()
    }

    func test013SelectingCurrentAppKeepsItInForeground() throws {
        app.terminate()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()
        app.buttons["Meine Apps"].firstMatch.tap()
        let host = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "zLoader\n")).firstMatch
        XCTAssertTrue(host.waitForExistence(timeout: 10))
        host.tap()
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertFalse(app.staticTexts["Vorgang fehlgeschlagen"].exists)
        attach("settings087-current-host-launch")
    }

    func test009OfflineSigningAndLocalizedAppActions() throws {
        app.terminate()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        let myApps = app.buttons["Meine Apps"].firstMatch
        XCTAssertTrue(myApps.waitForExistence(timeout: 20))
        myApps.tap()
        let add = app.buttons["my-apps-add"]
        let sign = app.buttons["my-apps-sign"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        XCTAssertTrue(sign.exists)
        XCTAssertLessThan(add.frame.midX, app.frame.midX)
        XCTAssertGreaterThan(sign.frame.midX, app.frame.midX)
        attach("signing085-tabs-and-toolbar")
        add.tap()
        XCTAssertTrue(app.buttons["Aus Dateien wählen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Über URL installieren"].exists)
        XCTAssertTrue(app.buttons["Aus IPA-Bibliothek wählen"].exists)
        XCTAssertFalse(app.buttons["Choose from Files"].exists)
        attach("signing085-german-add-menu")
        app.buttons["Über URL installieren"].tap()
        XCTAssertTrue(app.alerts.staticTexts["Gib die URL der zu installierenden IPA-Datei ein."].waitForExistence(timeout: 5))
        app.alerts.buttons["Abbrechen"].tap()
        sign.tap()
        let method = app.buttons["signing-method"]
        for _ in 0..<6 where !method.isHittable { app.swipeUp() }
        XCTAssertTrue(method.waitForExistence(timeout: 10))
        method.tap()
        XCTAssertTrue(app.buttons["Importiertes Zertifikat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Apple-Account"].exists)
        app.buttons["Importiertes Zertifikat"].tap()
        let configure = app.buttons["signing-import-identity"]
        XCTAssertTrue(configure.waitForExistence(timeout: 5))
        attach("signing085-imported-without-account")
        configure.tap()
        XCTAssertTrue(app.buttons["Import Certificate and Private Key"].exists || app.buttons["Zertifikat und privaten Schlüssel importieren"].exists)
        XCTAssertTrue(app.buttons["Provisioning-Profile importieren"].exists)
        XCTAssertTrue(app.buttons["Speichern"].exists)
        XCTAssertFalse(app.buttons["Save"].exists)
        XCTAssertEqual(app.navigationBars.count, 1)
        attach("signing085-certificate-profile-editor")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["signing-root-back"].tap()
        XCTAssertTrue(sign.waitForExistence(timeout: 5))
        app.buttons["Einstellungen"].firstMatch.tap()
        let identities = app.cells["settings-signing-identities"]
        for _ in 0..<10 where !identities.isHittable { app.swipeUp() }
        XCTAssertTrue(identities.isHittable)
        identities.tap()
        app.buttons["certificates-signing-configuration"].tap()
        XCTAssertTrue(app.buttons["app-operations-signing-method"].waitForExistence(timeout: 10))
        app.buttons["app-operations-signing-method"].tap()
        app.buttons["Importiertes Zertifikat"].tap()
        XCTAssertTrue(app.buttons["app-operations-import-identity"].waitForExistence(timeout: 5))
        attach("signing085-imported-install-refresh")
        // Leave the simulator's persistent operation selection as it was.
        app.buttons["app-operations-signing-method"].tap()
        app.buttons["Apple-Account"].tap()
    }

    func test010SimpleCertificatesAndSigningRequest() throws {
        openCertificates()
        XCTAssertTrue(app.buttons["certificates-add"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.navigationBars.count, 1)
        // UIKit's menu wrapper also exposes an unnamed internal button.
        XCTAssertEqual(app.navigationBars.buttons.matching(NSPredicate(format: "label != ''")).count, 2)
        XCTAssertFalse(app.staticTexts["Aktives lokales Zertifikat"].exists)
        attach("certificates086-overview-light")
        app.buttons["certificates-add"].tap()
        for identifier in ["certificates-request", "certificates-create-apple", "certificates-import-file", "certificates-import-portal"] {
            XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 5))
        }
        attach("certificates086-plus-menu")
        app.buttons["certificates-create-apple"].tap()
        XCTAssertTrue(app.navigationBars["Apple-Zertifikat erstellen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["certificates-create-confirm"].isEnabled)
        app.buttons["Abbrechen"].tap()

        app.buttons["certificates-add"].tap()
        app.buttons["certificates-request"].tap()
        let requestName = "zLoader UI Request " + String(UUID().uuidString.prefix(8))
        let field = app.textFields["certificate-request-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(requestName)
        attach("certificates086-request-form")
        app.buttons["certificate-request-create"].tap()
        let request = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "certificate-request-row-"))
            .containing(.staticText, identifier: requestName).firstMatch
        XCTAssertTrue(request.waitForExistence(timeout: 20))
        attach("certificates086-saved-request")
        request.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "certificate-request-actions-")).firstMatch.tap()
        app.buttons["Anfrage löschen…"].tap()
        app.alerts.buttons["Abbrechen"].tap()
        XCTAssertTrue(request.exists)
        request.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "certificate-request-actions-")).firstMatch.tap()
        app.buttons["Anfrage löschen…"].tap()
        app.alerts.buttons["Löschen"].tap()
        XCTAssertFalse(request.waitForExistence(timeout: 2))

        app.buttons["certificates-add"].tap()
        app.buttons["certificates-import-portal"].tap()
        XCTAssertTrue(app.buttons["Fertig"].waitForExistence(timeout: 5))
        attach("certificates086-portal")
        app.buttons["Fertig"].tap()
        XCTAssertTrue(app.buttons["certificates-add"].waitForExistence(timeout: 5))
    }

    func test011CertificateImportAndDirectActivation() throws {
        openCertificates()
        app.buttons["certificates-add"].tap()
        app.buttons["certificates-import-file"].tap()
        let browse = app.buttons.matching(NSPredicate(format: "label IN %@", ["Browse", "Durchsuchen"])).firstMatch
        if browse.waitForExistence(timeout: 3) { browse.tap() }
        let local = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["On My iPhone", "Auf meinem iPhone"])).firstMatch
        if local.waitForExistence(timeout: 3) { local.tap() }
        let folder = app.staticTexts["zLoader"].firstMatch
        if folder.waitForExistence(timeout: 3) { folder.tap() }
        let file = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["Certificate-UI-086", "Certificate-UI-086.p12"])).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 10), "Seed the generated certificate fixture into the simulator's Documents folder")
        file.tap()
        let open = app.buttons.matching(NSPredicate(format: "label IN %@", ["Open", "Öffnen"])).firstMatch
        if open.waitForExistence(timeout: 3) { open.tap() }
        let password = app.secureTextFields.firstMatch
        XCTAssertTrue(password.waitForExistence(timeout: 10))
        password.tap()
        password.typeText("ui-test-password")
        app.alerts.buttons.matching(NSPredicate(format: "label IN %@", ["Import", "Importieren"])).firstMatch.tap()
        XCTAssertTrue(app.alerts.buttons["OK"].waitForExistence(timeout: 10))
        app.alerts.buttons["OK"].tap()
        let row = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "certificate-row-"))
            .containing(.staticText, identifier: "zLoader UI Certificate").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let use = row.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "certificate-use-")).firstMatch
        XCTAssertTrue(use.exists)
        let useID = use.identifier
        let previousActive = app.buttons.matching(NSPredicate(format: "label == %@", "Zertifikat deaktivieren")).firstMatch
        let previousUseID = previousActive.exists ? previousActive.identifier : nil
        use.tap()
        XCTAssertEqual(app.buttons[useID].label, "Zertifikat deaktivieren")
        XCTAssertFalse(app.alerts.firstMatch.exists)
        attach("certificates086-active-light")

        // Restart to verify persisted certificate selection and the dark palette.
        openCertificates(appearance: "dark")
        XCTAssertTrue(app.buttons[useID].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons[useID].label, "Zertifikat deaktivieren")
        attach("certificates086-active-dark")
        app.buttons[useID].tap()
        XCTAssertEqual(app.buttons[useID].label, "Zertifikat verwenden")
        XCTAssertFalse(app.alerts.firstMatch.exists)
        let actions = row.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "certificate-actions-")).firstMatch
        actions.tap()
        app.buttons["Details"].tap()
        XCTAssertTrue(app.navigationBars["Zertifikatsdetails"].waitForExistence(timeout: 5) || app.navigationBars["Certificate Details"].exists)
        XCTAssertEqual(app.navigationBars.count, 1)
        app.navigationBars.buttons.firstMatch.tap()
        actions.tap()
        app.buttons["Nur lokal löschen…"].tap()
        app.alerts.buttons.matching(NSPredicate(format: "label IN %@", ["Delete", "Löschen"])).firstMatch.tap()
        if app.alerts.buttons["OK"].waitForExistence(timeout: 5) { app.alerts.buttons["OK"].tap() }
        XCTAssertFalse(row.exists)
        if let previousUseID, app.buttons[previousUseID].exists { app.buttons[previousUseID].tap() }
    }

    private func openCertificates(appearance: String = "light") {
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE", "-hasCompletedOnboarding", "YES", "-zLoader.appearance", appearance]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        let settings = app.buttons["Einstellungen"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 20))
        settings.tap()
        let certificates = app.cells["settings-signing-identities"]
        for _ in 0..<10 where !certificates.isHittable { app.swipeUp() }
        XCTAssertTrue(certificates.isHittable)
        certificates.tap()
        XCTAssertTrue(app.buttons["certificates-add"].waitForExistence(timeout: 10))
    }

    @discardableResult private func selectIdentity(virtual: Bool) -> String {
        app.tabBars.buttons["Einstellungen"].tap()
        let container = app.staticTexts["Container-Einstellungen"].firstMatch
        for _ in 0..<8 where !container.isHittable { app.swipeUp() }
        container.tap()
        app.buttons["container-device-identity-settings"].tap()
        app.buttons["container-device-identity-mode"].tap()
        let choice = virtual ? "Virtuelle Geräteidentität verwenden" : "Host-Gerät verwenden"
        let button = app.buttons[choice].firstMatch
        if button.exists { button.tap() } else { app.staticTexts[choice].firstMatch.tap() }
        let idfv = app.staticTexts["container-shared-idfv"]
        XCTAssertTrue(idfv.waitForExistence(timeout: 5))
        return idfv.label
    }

    private func launchContainer(_ name: String) {
        app.tabBars.buttons["Meine Apps"].tap()
        let pages = app.segmentedControls["my-apps-pages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 15))
        pages.buttons["Apps in Containern"].tap()
        let run = app.buttons["container-app-run-de.zloader.acceptance." + name]
        XCTAssertTrue(run.waitForExistence(timeout: 10))
        run.tap()
        XCTAssertTrue(app.staticTexts["fixture-title"].waitForExistence(timeout: 20))
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
