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
        var snapshot = dataSource.snapshot()

        for item in coordinator.items {
            guard let draggedItem = item.dragItem.localObject as? Item else { continue }
            
            let dropPoint = coordinator.session.location(in: collectionView)
            let destinationIndexPath = getDestinationIndexPath(for: draggedItem,
                                                               proposedDestination: coordinator.destinationIndexPath, 
                                                               dropPoint: dropPoint)
            
            guard let currentIndex = snapshot.indexOfItem(draggedItem) else { continue }
            
            if currentIndex != destinationIndexPath.item {
                if destinationIndexPath.item < snapshot.itemIdentifiers.count {
                    let toItem = snapshot.itemIdentifiers[destinationIndexPath.item]
                    if toItem != draggedItem {
                        snapshot.moveItem(draggedItem, beforeItem: toItem)
                    }
                } else if let lastItem = snapshot.itemIdentifiers.last, lastItem != draggedItem {
                    snapshot.moveItem(draggedItem, afterItem: lastItem)
                }
            }
            
            indexPaths.append(destinationIndexPath)
        }
        
        dataSource.apply(snapshot, animatingDifferences: true) {
            self.collectionView.collectionViewLayout.invalidateLayout()
        }
        
        for (index, item) in coordinator.items.enumerated() {
            coordinator.drop(item.dragItem, toItemAt: indexPaths[index])
        }
    }
    
    private func getDestinationIndexPath(for draggedItem: Item, 
                                         proposedDestination: IndexPath?, 
                                         dropPoint: CGPoint) -> IndexPath {
        let itemCount = collectionView.numberOfItems(inSection: 0)
        
        if itemCount == 0 {
            return IndexPath(item: 0,
                             section: 0)
        }
        
        let closestIndexPath = findClosestIndexPath(for: draggedItem, dropPoint: dropPoint)
        
        switch draggedItem.size {
        case .small:
            return getDestinationForSmallItem(proposedDestination: proposedDestination,
                                              dropPoint: dropPoint,
                                              closestIndexPath: closestIndexPath,
                                              itemCount: itemCount)
        case .medium:
            return getDestinationForMediumItem(proposedDestination: proposedDestination,
                                               dropPoint: dropPoint,
                                               closestIndexPath: closestIndexPath,
                                               itemCount: itemCount)
        }
    }

    private func findClosestIndexPath(for draggedItem: Item,
                                      dropPoint: CGPoint) -> IndexPath {
        var closestIndexPath: IndexPath = IndexPath(item: 0, section: 0)
        var closestDistance: CGFloat = .greatestFiniteMagnitude
        
        let itemCount = collectionView.numberOfItems(inSection: 0)
        for i in 0..<itemCount {
            let indexPath = IndexPath(item: i,
                                      section: 0)
            if let attributes = collectionView.layoutAttributesForItem(at: indexPath) {
                let distance: CGFloat
                if draggedItem.size == .small {
                    distance = abs(attributes.frame.midY - dropPoint.y)
                } else {
                    distance = hypot(attributes.frame.midX - dropPoint.x, attributes.frame.midY - dropPoint.y)
                }
                if distance < closestDistance {
                    closestDistance = distance
                    closestIndexPath = indexPath
                }
            }
        }
        
        return closestIndexPath
    }

    private func isValidDestination(_ indexPath: IndexPath,
                                    for dropPoint: CGPoint,
                                    size: CellSize) -> Bool {
        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
            return false
        }
        
        let frame = attributes.frame
        
        switch size {
        case .small:
            let xRange = (frame.minX - frame.width/2)...(frame.maxX + frame.width/2)
            let yRange = (frame.minY - frame.height/2)...(frame.maxY + frame.height/2)

            return xRange.contains(dropPoint.x) && yRange.contains(dropPoint.y)
            
        case .medium:
            let xRange = (frame.minX - frame.width*1.5)...(frame.maxX + frame.width*1.5)
            let yRange = (frame.minY - frame.height*1.5)...(frame.maxY + frame.height*1.5)
            return xRange.contains(dropPoint.x) && yRange.contains(dropPoint.y)
        }
    }

    private func getDestinationForSmallItem(proposedDestination: IndexPath?,
                                            dropPoint: CGPoint,
                                            closestIndexPath: IndexPath,
                                            itemCount: Int) -> IndexPath {
        if let proposedDestination = proposedDestination, 
           isValidDestination(proposedDestination,
            for: dropPoint,
             size: .small) {
            print("🐥 Using proposed destination for small item: \(proposedDestination)")
            return proposedDestination
        } else {
            if let lastItemAttributes = collectionView.layoutAttributesForItem(at: IndexPath(item: itemCount - 1, section: 0)),
               dropPoint.y > lastItemAttributes.frame.maxY {
                print("🐥 Dropping small item at the end: \(IndexPath(item: itemCount, section: 0))")
                return IndexPath(item: itemCount, section: 0)
            } else {
                let nextItem = min(closestIndexPath.item + 1,
                                   itemCount)
                print("🐥 Next nearest item will be at \(IndexPath(item: nextItem, section: 0))")
                return IndexPath(item: nextItem, section: 0)
            }
        }
    }

    private func getDestinationForMediumItem(proposedDestination: IndexPath?,
                                             dropPoint: CGPoint,
                                             closestIndexPath: IndexPath,
                                             itemCount: Int) -> IndexPath {
        if let proposedDestination = proposedDestination,
           isValidDestination(proposedDestination,
                              for: dropPoint,
                              size: .medium) {
            print("🐥 Using proposed destination for small item: \(proposedDestination)")
            return proposedDestination
        } else {
            if let lastItemAttributes = collectionView.layoutAttributesForItem(at: IndexPath(item: itemCount - 1, section: 0)),
               dropPoint.y > lastItemAttributes.frame.maxY {
                print("🐥 Dropping small item at the end: \(IndexPath(item: itemCount, section: 0))")
                return IndexPath(item: itemCount, section: 0)
            } else {
                let nextItem = min(closestIndexPath.item,
                                   itemCount)
                print("🐥 Next nearest item will be at \(IndexPath(item: nextItem, section: 0))")
                return IndexPath(item: nextItem, section: 0)
            }
        }
    }
}

