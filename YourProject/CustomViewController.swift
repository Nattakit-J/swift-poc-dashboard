//
//  CustomViewController.swift
//  YourProject
//
//  Created by IntrodexMac on 17/5/2567 BE.
//

import Foundation
import UIKit
import SnapKit

class CustomViewController: UIViewController {
    // MARK: - Properties
    private lazy var collectionView: UICollectionView = {
        let layout = createLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(CollectionViewCell.self, forCellWithReuseIdentifier: CollectionViewCell.reuseIdentifier)
        return collectionView
    }()
    
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var dragAndDropManager: DragAndDropManager!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureDataSource()
        setupDragAndDrop()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { $0.edges.equalToSuperview() }
        collectionView.delegate = self
    }
    
    // MARK: - Collection View Layout
    private func createLayout() -> UICollectionViewLayout {
        let layout = CustomFlowLayout()
        layout.minimumInteritemSpacing = 20
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        return layout
    }
    
    // MARK: - Data Source Configuration
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) {
            (collectionView, indexPath, item) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CollectionViewCell.reuseIdentifier, for: indexPath) as? CollectionViewCell else {
                fatalError("Unable to dequeue CollectionViewCell")
            }
            cell.configure(with: item)
            return cell
        }
        
        applyInitialSnapshot()
    }
    
    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.main])
        snapshot.appendItems([
            Item(size: .small, color: .softRed),
            Item(size: .small, color: .softBlue),
            Item(size: .small, color: .softGreen),
            Item(size: .medium, color: .softYellow),
            Item(size: .small, color: .softOrange),
            Item(size: .medium, color: .softPurple)
        ])
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    // MARK: - Drag and Drop Setup
    private func setupDragAndDrop() {
        dragAndDropManager = DragAndDropManager(collectionView: collectionView, dataSource: dataSource)
        collectionView.dragDelegate = dragAndDropManager
        collectionView.dropDelegate = dragAndDropManager
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension CustomViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return CGSize(width: collectionView.bounds.width - 40, height: 100)
        }
        
        let availableWidth = collectionView.bounds.width - 40
        switch item.size {
        case .small:
            return CGSize(width: (availableWidth - 20) / 2, height: 100)
        case .medium:
            return CGSize(width: availableWidth, height: 100)
        }
    }
}

// MARK: - Models
enum Section {
    case main
}

struct Item: Hashable {
    let id = UUID()
    let size: CellSize
    let color: UIColor
}

enum CellSize {
    case small
    case medium
}

// MARK: - Custom Flow Layout
class CustomFlowLayout: UICollectionViewFlowLayout {
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else { return nil }
        
        var leftMargin = sectionInset.left
        var maxY: CGFloat = -1.0
        
        attributes.forEach { layoutAttribute in
            if layoutAttribute.frame.origin.y >= maxY {
                leftMargin = sectionInset.left
            }
            
            layoutAttribute.frame.origin.x = leftMargin
            
            leftMargin += layoutAttribute.frame.width + minimumInteritemSpacing
            maxY = max(layoutAttribute.frame.maxY, maxY)
        }
        
        return attributes
    }
}

// MARK: - UIColor Extensions
extension UIColor {
    static let softRed = UIColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1.0)
    static let softBlue = UIColor(red: 0.22, green: 0.59, blue: 0.94, alpha: 1.0)
    static let softGreen = UIColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1.0)
    static let softYellow = UIColor(red: 0.95, green: 0.61, blue: 0.07, alpha: 1.0)
    static let softOrange = UIColor(red: 0.90, green: 0.49, blue: 0.13, alpha: 1.0)
    static let softPurple = UIColor(red: 0.61, green: 0.35, blue: 0.71, alpha: 1.0)
}
