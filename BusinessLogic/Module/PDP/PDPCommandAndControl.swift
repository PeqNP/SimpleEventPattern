/**
 Provides the Command & Control service for the Product Page (PDP).
 
 NOTES:
 When looking through the code, notice how each method performs a single operation (single responsibility). This was a pattern that was discovered after 1. the business logic was moved out of the C&C and into the BL 2. the necessity to clearly describe a set of discrete operations that must take place in a given sequence with the help of the `EventQueue`.
 
 Copyright © 2018 Upstart Illustration LLC. All rights reserved.
 */

import Foundation

enum PDPCommand {
    case update(PDPViewState)
    case showLoadingIndicator
    case hideLoadingIndicator
    case showShippingInfo(ShippingInfoViewState)
    case showMoreInfo
    case showImageGallery
    case routeToPDPFor(ProductID)
    case showError(Error)
}

enum PDPEvent {
    case configure(Product)
    case viewDidLoad
    case selectedSKUSize(SKUSize)
    case selectedSKUColor(SKUColor)
    case tappedMoreInfoButton
    case tappedCarouselImage
    case tappedRecommendedProduct(ProductID)
    case requestedShippingInformation
    case addOneTapped
    case removeOneTapped
    case addToBagTapped
}

protocol PDPCommandAndControlDelegate: class {
    func command(_ action: PDPCommand)
}

class PDPCommandAndControl {
    
    private let queue: EventQueue = EventQueue()
    private var state: PDPBusinessLogic!

    private let shippingService: ShippingService
    private let logicFactory: PDPBusinessLogicFactory
    private let viewStateFactory: PDPViewStateFactory

    weak var delegate: PDPCommandAndControlDelegate?
    
    init(shippingService: ShippingService, logicFactory: PDPBusinessLogicFactory, viewStateFactory: PDPViewStateFactory) {
        self.shippingService = shippingService
        self.logicFactory = logicFactory
        self.viewStateFactory = viewStateFactory
    }
    
    // MARK: - Internal Methods
    
    func receive(_ event: PDPEvent) {
        switch event {
        case .configure(let product):
            state = logicFactory.makeFromProduct(product)
        case .viewDidLoad:
            break
        case .selectedSKUSize(let size):
            selectedSKUSize(size)
        case .selectedSKUColor(let color):
            selectedSKUColor(color)
        case .tappedMoreInfoButton:
            tappedMoreInfoButton()
        case .tappedCarouselImage:
            tappedCarouselImage()
        case .tappedRecommendedProduct(let productID):
            tappedRecommendedProduct(productID)
        case .requestedShippingInformation:
            requestedShippingInformation()
        case .addOneTapped:
            addOneTapped()
        case .removeOneTapped:
            removeOneTapped()
        case .addToBagTapped:
            addToBagTapped()
        }
    }
    
    // MARK: - Private Methods

    // MARK: Events
    
    private func selectedSKUSize(_ size: SKUSize) {
        // TODO: Will need to return an enumerated value
        let state = self.state.selectSKUSize(size)
        update(with: state)
    }
    
    private func selectedSKUColor(_ color: SKUColor) {
        let state = self.state.selectSKUColor(color)
        update(with: state)
    }
    
    private func tappedMoreInfoButton() {
        delegate?.command(.showMoreInfo)
    }
    
    private func tappedCarouselImage() {
        delegate?.command(.showImageGallery)
    }
    
    private func tappedRecommendedProduct(_ productID: ProductID) {
        delegate?.command(.routeToPDPFor(productID))
    }
    
    /**
     Request shipping information on-demand.
     
     This shows how you can chain several `PDPCommand`s together.
     */
    private func requestedShippingInformation() {
        queue
            .add(showLoadingIndicator)
            .add(loadShippingInformation)
            .add(hideLoadingIndicator)
            .execute()
    }
    
    private func addOneTapped() {
        let result = self.state.addOneMoreToPurchase()
        update(with: result)
    }
    
    private func removeOneTapped() {
        let result = self.state.removeOneFromPurchase()
        update(with: result)
    }
    
    /**
     Adds the selected SKU to the bag with the requested amount.
     
     This shows how you can chain several `PDPCommand`s together using a `EventQueue.JobFinishedCallback`.
     */
    private func addToBagTapped() {
        queue
            .add(showLoadingIndicator)
            .add(addSKUToBag)
            .add(hideLoadingIndicator)
            .execute()
    }
    
    // MARK: Helpers
    
    // TODO: Add a feature where the `BusinessLogic` determines if the user should be routed.
    
    private func showLoadingIndicator() {
        delegate?.command(.showLoadingIndicator)
    }
    
    private func hideLoadingIndicator() {
        delegate?.command(.hideLoadingIndicator)
    }

    /**
     Load shipping information for a product on-demand.
 
     This method shows how an event unrelated to the main `PDPState` can be handled. You could potentially have a `ShippingInfoBusinessLogic` but that's unnecessary as the operation is so simple.
     */
    private func loadShippingInformation() -> QueueableFuture? {
        return shippingService.shippingInformationFor(productID: state.productID)
            .onSuccess { [weak self] (shippingInfo) in
                self?.showShippingInfo(shippingInfo)
            }
            .onFailure { [weak self] (error) in
                self?.showError(error)
            }
            .makeQueueable()
    }
    
    /**
     Add the selected SKU to the shopper's bag.
     */
    private func addSKUToBag() -> QueueableFuture? {
        // TODO: Make service call to add SKU to bag
        let result = self.state.addSKUToBag()
        update(with: result)
        return QueueableFuture()
    }
    
    private func showShippingInfo(_ shippingInfo: ShippingInfo) {
        let viewState = viewStateFactory.makeShippingInfoViewStateFrom(shippingInfo: shippingInfo)
        delegate?.command(.showShippingInfo(viewState))
    }
    
    /**
     Show an error.
     
     The `Error` in this context is purposely generic as it can handle `Error`s from `Service`s, `BusinessLogic`, or any other dependency.
     */
    private func showError(_ error: Error) {
        delegate?.command(.showError(error))
    }
    
    private func update(with result: PDPStateResult) {
        switch result {
        case .success(let state):
            self.state = state
            let viewState = viewStateFactory.makePDPViewStateFrom(state: state)
            delegate?.command(.update(viewState))
        case .error(let error):
            showError(error)
        }
    }
}
