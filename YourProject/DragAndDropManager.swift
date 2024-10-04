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
            
            let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(item: snapshot.itemIdentifiers.count, section: 0)
            
            if draggedItem.size == .small {
                // Find the best position for the small item
                let bestIndexPath = findBestPositionForSmallItem(draggedItem, nearIndexPath: destinationIndexPath, in: snapshot)
                if bestIndexPath.item < snapshot.itemIdentifiers.count {
                    snapshot.insertItems([draggedItem], beforeItem: snapshot.itemIdentifiers[bestIndexPath.item])
                } else {
                    snapshot.appendItems([draggedItem])
                }
                indexPaths.append(bestIndexPath)
            } else {
                // For medium items, just insert at the destination
                if destinationIndexPath.item < snapshot.itemIdentifiers.count {
                    snapshot.insertItems([draggedItem], beforeItem: snapshot.itemIdentifiers[destinationIndexPath.item])
                } else {
                    snapshot.appendItems([draggedItem])
                }
                indexPaths.append(destinationIndexPath)
            }
            
            dataSource.apply(snapshot, animatingDifferences: true) {
                self.collectionView.collectionViewLayout.invalidateLayout()
            }
        }
        
        // Perform the drop for all items
        for (index, item) in coordinator.items.enumerated() {
            coordinator.drop(item.dragItem, toItemAt: indexPaths[index])
        }
    }
    
    private func findBestPositionForSmallItem(_ item: Item,
                                              nearIndexPath indexPath: IndexPath,
                                              in snapshot: NSDiffableDataSourceSnapshot<Section, Item>) -> IndexPath {
        let items = snapshot.itemIdentifiers
        
        // Check if we can pair with another small item
        if indexPath.item > 0 && items[indexPath.item - 1].size == .small {
            return IndexPath(item: indexPath.item, section: 0)
        } else if indexPath.item < items.count - 1 && items[indexPath.item + 1].size == .small {
            return indexPath
        }
        
        // If we can't pair, find the next available slot
        for i in indexPath.item..<items.count {
            if items[i].size == .medium {
                return IndexPath(item: i, section: 0)
            }
        }
        
        // If no slot found, append to the end
        return IndexPath(item: items.count, section: 0)
    }
}
