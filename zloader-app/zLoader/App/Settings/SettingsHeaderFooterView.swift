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
        if disclosureButton.superview == nil, let row = primaryLabel.superview as? UIStackView {
            row.insertArrangedSubview(disclosureButton, at: 0)
        }
        var configuration = UIButton.Configuration.plain()
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
    override init(reuseIdentifier: String?)
    {
        super.init(reuseIdentifier: reuseIdentifier)

        primaryLabel = UILabel()
        secondaryLabel = UILabel()
        button = UIButton(type: .system)
        primaryLabel.font = UIFont.systemFont(ofSize: 14)
        primaryLabel.textColor = .secondaryLabel
        primaryLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        secondaryLabel.font = UIFont.systemFont(ofSize: 14)
        secondaryLabel.textColor = .secondaryLabel
        secondaryLabel.numberOfLines = 0
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)

        let titleRow = UIStackView(arrangedSubviews: [primaryLabel, button])
        titleRow.distribution = .equalSpacing
        stackView = UIStackView(arrangedSubviews: [titleRow, secondaryLabel])
        stackView.axis = .vertical
        layoutMargins = UIEdgeInsets(top: 8, left: 30, bottom: 8, right: 30)
        configureLayout()
    }

    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
    }

    override func awakeFromNib()
    {
        super.awakeFromNib()
        primaryLabel.textColor = .secondaryLabel
        secondaryLabel.textColor = .secondaryLabel
        button.setTitleColor(.altPrimary, for: .normal)
        configureLayout()
    }

    private func configureLayout()
    {
        primaryLabel.font = .preferredFont(forTextStyle: .footnote)
        secondaryLabel.font = .preferredFont(forTextStyle: .footnote)
        primaryLabel.adjustsFontForContentSizeCategory = true
        secondaryLabel.adjustsFontForContentSizeCategory = true
        self.contentView.layoutMargins = .zero
        self.contentView.preservesSuperviewLayoutMargins = true
        
        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.stackView)
        
        NSLayoutConstraint.activate([self.stackView.leadingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.leadingAnchor),
                                     self.stackView.trailingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.trailingAnchor),
                                     self.stackView.topAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.topAnchor),
                                     self.stackView.bottomAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.bottomAnchor)])
    }
}
