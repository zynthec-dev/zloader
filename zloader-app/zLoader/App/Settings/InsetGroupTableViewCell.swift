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

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundConfiguration = .listCell()
        if let legacyChevron = contentView.viewWithTag(77424) {
            legacyChevron.isHidden = true
            accessoryType = .disclosureIndicator
        }
    }

    func valueRowHeight(for width: CGFloat) -> CGFloat { UITableView.automaticDimension }
}
