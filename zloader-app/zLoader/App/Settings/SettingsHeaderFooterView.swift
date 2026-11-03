//
//  SettingsHeaderFooterView.swift
//  ZLoader
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit


final class SettingsHeaderFooterView: UITableViewHeaderFooterView
{
    @IBOutlet var primaryLabel: UILabel!
    @IBOutlet var secondaryLabel: UILabel!
    @IBOutlet var button: UIButton!
        
    @IBOutlet private var stackView: UIStackView!
    private let disclosureButton = UIButton(type: .system)
    private var disclosureAction: UIAction?

    func resetDisclosure() {
        disclosureButton.isHidden = true
        if let disclosureAction { disclosureButton.removeAction(disclosureAction, for: .primaryActionTriggered) }
        disclosureAction = nil
    }

    func configureDisclosure(identifier: String, collapsed: Bool, action: @escaping () -> Void) {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = .zero
        configuration.title = primaryLabel.text
        configuration.image = UIImage(systemName: collapsed ? "chevron.forward" : "chevron.down")
        configuration.imagePlacement = .trailing
        configuration.titleLineBreakMode = .byWordWrapping
        configuration.baseForegroundColor = .secondaryLabel
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .footnote)
            return attributes
        }
        disclosureButton.configuration = configuration
        disclosureButton.contentHorizontalAlignment = .leading
        disclosureButton.accessibilityIdentifier = identifier
        disclosureButton.accessibilityValue = String(localized: collapsed ? "Collapsed" : "Expanded", table: "SettingsLayout")
        disclosureButton.isHidden = false
        primaryLabel.isHidden = true
        let handler = UIAction { _ in action() }
        disclosureAction = handler
        disclosureButton.addAction(handler, for: .primaryActionTriggered)
    }
    func configureMargins(isHeader: Bool) {
        let configuration = isHeader ? UIListContentConfiguration.header() : UIListContentConfiguration.footer()
        contentView.directionalLayoutMargins = configuration.directionalLayoutMargins
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        primaryLabel = UILabel()
        secondaryLabel = UILabel()
        button = UIButton(type: .system)
        button.isHidden = true
        primaryLabel.font = .preferredFont(forTextStyle: .footnote)
        secondaryLabel.font = .preferredFont(forTextStyle: .footnote)
        primaryLabel.textColor = .secondaryLabel
        secondaryLabel.textColor = .secondaryLabel
        primaryLabel.numberOfLines = 0
        secondaryLabel.numberOfLines = 0
        primaryLabel.adjustsFontForContentSizeCategory = true
        secondaryLabel.adjustsFontForContentSizeCategory = true
        stackView = UIStackView(arrangedSubviews: [primaryLabel, secondaryLabel, disclosureButton])
        stackView.axis = .vertical
        disclosureButton.isHidden = true
        configureLayout()
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func awakeFromNib() {
        super.awakeFromNib()
        configureLayout()
    }

    private func configureLayout() {
        contentView.preservesSuperviewLayoutMargins = true
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
        ])
    }
}
