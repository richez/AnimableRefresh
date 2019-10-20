//
//  RefresherView.swift
//  Refresh
//
//  Created by Thibaut Richez on 10/19/19.
//  Copyright © 2019 Thibaut Richez. All rights reserved.
//

import UIKit

final class RefreshView: UIView {
    // MARK: - Interface Properties

    /// The scrollView on which the `RefreshView` operate its actions
    weak var scrollView: UIScrollView? {
        willSet {
            removeScrollViewObserving()
        }
        didSet {
            if let scrollView = scrollView {
                scrollViewDefaultInsets = scrollView.contentInset
                addScrollViewObserving()
            }
        }
    }

    // MARK: - Properties

    /// Represent the insets when the `scrollView` is at its initial position
    private(set) var scrollViewDefaultInsets: UIEdgeInsets = .zero

    /// Represent the previous offset before update.
    private(set) var previousScrollViewOffset: CGPoint = CGPoint.zero

    /// The pulling position at which the view should start the loading process.
    /// - Note: 1 by default (what appear to look best). A highter value will increase
    /// the amount of space the user has to pull down.
    var pullingPositionBeforeLoad: CGFloat = 1

    /// Define if the loading process should start before or after the user stopped pulling down.
    /// - Note: True by default (if set to false, the loading process will start once the user
    /// pull down at `pullingPositionBeforeLoad`. This can cause the same buggy effect as
    /// `UIRefreshControl` where the finished refreshing animation starts when the user is still
    /// pulling down.
    var waitForDraggingToEnd: Bool = true

    var height: CGFloat = 60

    /// A Boolean value that determines whether the view is visible or not by checking
    /// if the top of the `scrollView` is back to its initial position
    var isVisible: Bool {
        guard let scrollView = self.scrollView else { return false }
        return (scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
            <= -scrollViewDefaultInsets.top
    }

    /// Define the state in which the view is.
    /// Any change is followed by the corresponding animation
    private(set) var state: RefreshState = .inactive {
        didSet {
            self.handleStateChange(from: oldValue, to: state)
        }
    }

    /// The view that will be shown in the center of the `RefreshView`.
    /// It will be animated accordingly to `state` changes.
    private(set) var animableView: AnimableView
    /// The action that will be triggered on `RefreshView` loading animation
    private(set) var action: (() -> Void)?

    // MARK: ScrollView Observations retainer
    private var contentOffsetObserver: NSKeyValueObservation?
    private var contentInsetObserver: NSKeyValueObservation?

    // MARK: - Initialization

    /// - Parameters:
    ///    - animableView: The view that will be shown in the center of the `RefreshView` and
    ///    animated accordingly to `state` changes.
    ///    - action: The action that will be triggered during the loading animation
    init(animableView: AnimableView, action: (() -> Void)?) {
        self.animableView = animableView
        self.action = action
        super.init(frame: .zero)
        self.configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.removeScrollViewObserving()
    }

    // MARK: - LifeCycle

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let scrollView = self.scrollView else { return }
        self.frame = CGRect(origin: CGPoint(x: 0, y: -self.height),
                            size: CGSize(width: scrollView.frame.width, height: self.height))
    }

    // MARK: - Configuration

    private func configure() {
        self.autoresizingMask = [.flexibleWidth]
        self.configureAnimableView()
    }

    private func configureAnimableView() {
        self.animableView.isHidden = true
        self.animableView.autoresizingMask = [.flexibleWidth]
        self.animableView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(animableView)
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: animableView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 1),
            NSLayoutConstraint(item: animableView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 1),
            NSLayoutConstraint(item: animableView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: 1),
            NSLayoutConstraint(item: animableView, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 1)
        ])
    }

    // MARK: - Update state refresh

    /// Tells the view that the refresh operation was started programmatically.
    func startRefresh() {
        guard self.state == .inactive, let scrollView = scrollView else { return }
        let topInset = scrollView.safeAreaInsets.top
        let offsetY =  -self.frame.height - scrollViewDefaultInsets.top - topInset
        self.state = .loading
        scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: true)
    }

    /// Tells the view that the refresh operation has ended.
    func endRefresh() {
        guard self.state == .loading else { return }
        self.state = .finished
    }

    // MARK: - ScrollView observations

    /// In order to determine the `state` of the `RefreshView`, we need to observe the associated
    ///`scrollView` `contentOffset` and `ContentInset` for changes
    private func addScrollViewObserving() {
        guard let scrollView = self.scrollView else { return }
        contentOffsetObserver = scrollView.observe(\.contentOffset, options: [.new]) {
            [weak self] (_, _) in
            self?.handleScrollViewOffsetChange()
        }

        contentInsetObserver = scrollView.observe(\.contentInset, options: [.new]) {
            [weak self] (_, _) in
            self?.handleScrollViewInsetChange()
        }
    }

    private func removeScrollViewObserving() {
        self.contentOffsetObserver?.invalidate()
        self.contentOffsetObserver = nil
        self.contentInsetObserver?.invalidate()
        self.contentInsetObserver = nil
    }

    /// Called every time the `scrollView`'s `contentInsets` changes.
    /// This method set the `scrollViewDefaultInsets` by retrieving the `scrollView` `contentInset`
    /// when the state is `.inactive` (`scrollView` at initial position)
    private func handleScrollViewInsetChange() {
        guard self.state == .inactive, let scrollView = self.scrollView else { return }
        self.scrollViewDefaultInsets = scrollView.contentInset
    }

    /// Called every time the `scrollView`'s `contentOffset` changes.
    /// It determines in which state the `RefreshView` should be
    private func handleScrollViewOffsetChange() {
        guard let scrollView = self.scrollView else { return }
        let viewHeight = self.frame.size.height
        // Using the previous offsets instead of the current offsets give a smoother effect
        let currentOffset = self.previousScrollViewOffset.y + self.scrollViewDefaultInsets.top
        defer {
            previousScrollViewOffset.y = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        }
        // The `scrollView` is back to its initial position
        if currentOffset == 0, self.state != .loading {
            self.state = .inactive
            return
        }
        if self.state == .pulling(position: pullingPositionBeforeLoad),
            scrollView.isDragging == !self.waitForDraggingToEnd {
            self.state = .loading
        } else if self.state != .loading, self.state != .finished {
            // We evaluate how mutch the user pulled down the scroll view
            self.state = .pulling(position: -currentOffset / viewHeight)
        }
    }

    /// Called every time that the `state` changes.
    /// Determines the animations it should trigger
    private func handleStateChange(from oldState: RefreshState, to newState: RefreshState) {
        self.animableView.isHidden = (newState == .inactive)
        switch newState {
        case .loading:
            guard oldState != .loading else { return }
            self.animateLoading()
        case .pulling(position: let value) where value < 0.1:
            self.state = .inactive
        case .finished:
            if self.isVisible {
                self.animateFinished()
            } else {
                self.scrollView?.contentInset = self.scrollViewDefaultInsets
                self.state = .inactive
            }
        default: break
        }
    }

    // MARK: - Animations

    /// This animate the loading process by setting the `scrollView` offsets and insets
    /// so that the `RefreshView` is visible. It also animate the `animableView` and
    /// start the `action` completion.
    private func animateLoading() {
        guard let scrollView = self.scrollView else { return }
        scrollView.contentOffset = previousScrollViewOffset
        scrollView.bounces = false
        animableView.animate()
        UIView.animate(withDuration: 0.3, animations: {
            let insetY = self.frame.height + self.scrollViewDefaultInsets.top
            scrollView.contentInset.top = insetY
            scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: -insetY)
        }) { (_) in
            scrollView.bounces = true
        }
        action?()
    }

    /// This stops the `RefreshView` loading animation by positioning it back to its
    /// initial position. It also stop the `animableView` animation.
    private func animateFinished() {
        guard let scrollView = self.scrollView else { return }
        self.removeScrollViewObserving()
        animableView.stopAnimating()
        UIView.animate(
            withDuration: 1,
            delay: 0,
            usingSpringWithDamping: 0.4,
            initialSpringVelocity: 0.8,
            options: [.curveLinear],
            animations: {
                scrollView.contentInset = self.scrollViewDefaultInsets
            },
            completion: { _ in
                self.addScrollViewObserving()
                self.state = .inactive
            }
        )
    }
}
