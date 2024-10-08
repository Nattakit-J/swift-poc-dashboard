import UIKit

class DragAndDropManager: NSObject, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    private let collectionView: UICollectionView
    private let dataSource: UICollectionViewDiffableDataSource<Section, Item>
    
    init(collectionView: UICollectionView, dataSource: UICollectionViewDiffableDataSource<Section, Item>) {
        self.collectionView = collectionView
        self.dataSource = dataSource
    }
    
    // MARK: - UICollectionViewDragDelegate
    
    func collectionView(_ collectionView: UICollectionView,
                        itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath) -> [UIDragItem] {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return [] }
        let itemProvider = NSItemProvider(object: item.id.uuidString as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = item
        return [dragItem]
    }
    
    // MARK: - UICollectionViewDropDelegate
    
    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        return UICollectionViewDropProposal(operation: .move,
                                            intent: .insertAtDestinationIndexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        performDropWith coordinator: UICollectionViewDropCoordinator) {
        var indexPaths: [IndexPath] = []
        
        for item in coordinator.items {
            guard let draggedItem = item.dragItem.localObject as? Item else { continue }
            
            var snapshot = dataSource.snapshot()
            snapshot.deleteItems([draggedItem])
            
            let dropPoint = coordinator.session.location(in: collectionView)
            let destinationIndexPath = findNearestIndexPath(for: dropPoint)
            
            if destinationIndexPath.item < snapshot.itemIdentifiers.count {
                snapshot.insertItems([draggedItem], beforeItem: snapshot.itemIdentifiers[destinationIndexPath.item])
            } else {
                snapshot.appendItems([draggedItem])
            }
            indexPaths.append(destinationIndexPath)
            
            dataSource.apply(snapshot, animatingDifferences: true) {
                self.collectionView.collectionViewLayout.invalidateLayout()
            }
        }
        
        // Perform the drop for all items
        for (index, item) in coordinator.items.enumerated() {
            coordinator.drop(item.dragItem, toItemAt: indexPaths[index])
        }
    }
    
    private func findNearestIndexPath(for point: CGPoint) -> IndexPath {
        print("🦆🟡 findNearestIndexPath")
        
        let itemCount = collectionView.numberOfItems(inSection: 0)
        
        if itemCount == 0 {
            print("🦆🔵 Empty collection view")
            return IndexPath(item: 0, section: 0)
        }
        
        var closestIndexPath: IndexPath?
        var closestDistance: CGFloat = CGFloat.greatestFiniteMagnitude
        
        for i in 0..<itemCount {
            let indexPath = IndexPath(item: i, section: 0)
            if let attributes = collectionView.layoutAttributesForItem(at: indexPath) {
                let distance = abs(attributes.frame.midY - point.y)
                if distance < closestDistance {
                    closestDistance = distance
                    closestIndexPath = indexPath
                }
            }
        }
        
        if let closestIndexPath = closestIndexPath {
            // If we're at the last item, return it (don't try to go beyond)
            if closestIndexPath.item == itemCount - 1 {
                print("🦆🟢 Nearest item is the last one: \(closestIndexPath)")
                return closestIndexPath
            }
            
            // Otherwise, return the next index path
            let nextItem = closestIndexPath.item + 1
            print("🦆🟢 Next nearest item will be at \(IndexPath(item: nextItem, section: 0))")
            return IndexPath(item: nextItem, section: 0)
        } else {
            print("🦆🟣 Fallback: appending to the end")
            return IndexPath(item: itemCount, section: 0)
        }
    }
}
