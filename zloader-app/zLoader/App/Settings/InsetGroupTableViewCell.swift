//
//  InsetGroupTableViewCell.swift
//  ZLoader
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

extension InsetGroupTableViewCell
{
    @objc enum Style: Int
    {
        case single
        case top
        case middle
        case bottom
    }
}

/// Compatibility for the storyboard's grouped cells; UIKit owns row surfaces,
/// separators, selection and layout rather than a second card behind each row.
class InsetGroupTableViewCell: UITableViewCell {
#if !TARGET_INTERFACE_BUILDER
    @IBInspectable var style: Style = .single
#else
    @IBInspectable var style: Int = 0
#endif
    @IBInspectable var isSelectable: Bool = false

    // Keep source controls/labels alive for storyboard outlets and actions, while
    // UIListContentConfiguration owns their visible typography and row margins.
    private var sourceViews: [UIView]?
    private var sourceLabels: [UILabel] = []
    private var sourceAccessory: UIControl?

    private func labels(in view: UIView) -> [UILabel] {
        if view is UIControl { return [] }
        if let label = view as? UILabel { return [label] }
        return view.subviews.flatMap { labels(in: $0) }
    }

    func configureNativeContent() {
        if sourceViews == nil {
            let views = contentView.subviews
            sourceLabels = views.flatMap { labels(in: $0) }
            sourceAccessory = views.compactMap { $0 as? UIControl }.first
            sourceViews = views
            // Discard the storyboard's former custom 30-point insets as well.
            let nativeCell = UITableViewCell(style: .default, reuseIdentifier: nil)
            directionalLayoutMargins = nativeCell.directionalLayoutMargins
            contentView.directionalLayoutMargins = nativeCell.contentView.directionalLayoutMargins
            separatorInset = nativeCell.separatorInset
            // The original cell retains its segue and the original controls retain
            // their targets. Remove the old geometry rather than layering over it.
            for view in views { view.removeFromSuperview() }
            if let sourceAccessory {
                sourceAccessory.sizeToFit()
                accessoryView = sourceAccessory
            }
        }
        preservesSuperviewLayoutMargins = true
        contentView.preservesSuperviewLayoutMargins = true
        let title = sourceLabels.first?.text ?? ""
        var content = defaultContentConfiguration()
        content.text = title
        content.secondaryText = sourceLabels.dropFirst().compactMap(\.text).filter { !$0.isEmpty }.joined(separator: "\n")
        if content.secondaryText?.isEmpty == true { content.secondaryText = nil }
        content.image = UIImage(systemName: SettingsEntrySymbol.name(for: title), withConfiguration: UIImage.SymbolConfiguration(textStyle: .body))
        content.textProperties.color = .label
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 0
        content.imageProperties.tintColor = .altPrimary
        content.imageProperties.reservedLayoutSize = CGSize(width: UIListContentConfiguration.ImageProperties.standardDimension, height: UIListContentConfiguration.ImageProperties.standardDimension)
        contentConfiguration = content
        sourceAccessory?.accessibilityLabel = title
        tintColor = .altPrimary
        backgroundConfiguration = .listCell()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundConfiguration = .listCell()
        if contentView.viewWithTag(77424) != nil { accessoryType = .disclosureIndicator }
    }

    func valueRowHeight(for width: CGFloat) -> CGFloat { UITableView.automaticDimension }
}
