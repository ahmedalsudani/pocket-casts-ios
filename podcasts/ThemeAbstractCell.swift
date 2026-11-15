import UIKit

class ThemeAbstractCell: UICollectionViewCell {
    @IBOutlet var nameLabel: ThemeableLabel! {
        didSet {
            nameLabel.font = UIFont.font(ofSize: 15, weight: .medium, scalingWith: .subheadline)
        }
    }

    @IBOutlet var selectionView: ThemeableSelectionView! {
        didSet {
            selectionView.layer.borderWidth = 4
            selectionView.unselectedStyle = .primaryUi02
        }
    }

    @IBOutlet var imageView: UIImageView! {
        didSet {
            imageView.clipsToBounds = true
        }
    }

    @IBOutlet var shadowView: ThemeableView! {
        didSet {
            shadowView.clipsToBounds = false
            shadowView.layer.shadowColor = AppTheme.appearanceShadowColor.cgColor
            shadowView.layer.shadowOpacity = 1
            shadowView.layer.shadowRadius = 5
            shadowView.layer.cornerRadius = 10
            shadowView.layer.shadowOffset = CGSize(width: 0, height: 2)
        }
    }

    @IBOutlet var underShadowView: ThemeableView! {
        didSet {
            underShadowView.layer.cornerRadius = 10
            underShadowView.style = .contrast04
            underShadowView.alpha = 0.5
        }
    }

    @IBOutlet var cornerImage: UIImageView! {
        didSet {
            setCornerImage()
        }
    }

    private func setCornerImage() {
        cornerImage.image = isCellSelected ? UIImage(named: "tickBlueCircle") : nil
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.clipsToBounds = false
        clipsToBounds = false
    }

    var isCellSelected = false {
        didSet {
            selectionView.isSelected = isCellSelected
            setCornerImage()
        }
    }

    override func prepareForReuse() {
        isCellSelected = false
    }
}
