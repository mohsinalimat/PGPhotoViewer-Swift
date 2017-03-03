//
//  PGPagingScrollView.swift
//  PGPhotoSample
//
//  Created by ipagong on 2017. 3. 2..
//  Copyright © 2017년 ipagong. All rights reserved.
//

import UIKit

@objc
protocol PGPagingScrollViewDelegate {
    func pagingScrollView(_ pagingScrollView:PGPagingScrollView, willChangedCurrentPage currentPageIndex:NSInteger)
    func pagingScrollView(_ pagingScrollView:PGPagingScrollView, didChangedCurrentPage currentPageIndex:NSInteger)
    func pagingScrollView(_ pagingScrollView:PGPagingScrollView, layoutSubview view:UIView);
}
@objc
protocol PGPagingScrollViewDataSource {
    func pagingScrollView(_ pagingScrollView:PGPagingScrollView, recycledView view:UIView?, viewForIndex index:NSInteger) -> UIView
    func pagingScrollView(_ pagingScrollView:PGPagingScrollView, prepareShowPageView view:UIView, viewForIndex index:NSInteger)
    func startIndexOfPageWith(pagingScrollView:PGPagingScrollView) -> NSInteger
    func numberOfPageWith(pagingScrollView:PGPagingScrollView) -> NSInteger
}

@objc
class PGPagingScrollView: UIView, UIScrollViewDelegate {

    public var delegate:PGPagingScrollViewDelegate?
    public var dataSource:PGPagingScrollViewDataSource?
    
    private let lockQueue = DispatchQueue(label: "pagong.paging.control.lock")
    
    private var recyclePageCount:NSInteger = 2
    private var visiblePageCount:NSInteger = 3
    
    private var visiblePages = Dictionary<String, UIView>()
    private var recyclePages = Array<UIView>()
    
    private let scrollView = UIScrollView()
    
    init() {
        super.init(frame: CGRect.zero)
        setupViews()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    convenience init(frame: CGRect, delegate:PGPagingScrollViewDelegate, dataSource:PGPagingScrollViewDataSource) {
        self.init(frame: frame)
        self.delegate = delegate
        self.dataSource = dataSource
        setupViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }
    
    deinit {
        visiblePages.removeAll()
        recyclePages.removeAll()
        scrollView.removeFromSuperview()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        adjustLayout()
    }
    
    private func setupViews() {
        scrollView.frame = self.bounds
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.delegate = self
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.autoresizesSubviews = true
        scrollView.backgroundColor = UIColor.clear
        self.addSubview(scrollView)
        
        setupTotalPage()
        setupCurrentPageIndex()
        adjustLayout()
    }
    
    public private(set) var totalPage:NSInteger = 0
    
    public private(set) var currentPageIndex:NSInteger = 0 {
        willSet {
            guard newValue != currentPageIndex else { return }
            didStartViewingPageAt(index: newValue)
        }
    }
    
    // MARK: - private methods
    
    private func setupTotalPage() {
        totalPage = self.dataSource?.numberOfPageWith(pagingScrollView: self) ?? 0
    }
    
    private func setupCurrentPageIndex() {
        currentPageIndex = self.dataSource?.startIndexOfPageWith(pagingScrollView: self) ?? 0
    }
    
    private func adjustLayout() {
        
        self.scrollView.contentSize = contentSizeForPagingScrollView()
        
        visiblePages.values.forEach { self.subPageViewLayout(view: $0) }
        
        recyclePages.forEach { self.subPageViewLayout(view: $0) }
        
        jumpToPage(at: self.currentPageIndex, animated:false)
    }

    private func subPageViewLayout(view:UIView) {
        
        var viewFrame:CGRect = self.scrollView.bounds;
        
        viewFrame.origin.x = contentOffsetForPageAt(index: view.tag).x
        
        view.frame = viewFrame;
        
        self.delegate?.pagingScrollView(self, layoutSubview: view)
        
        view.layoutSubviews()
    }
    
    private func contentSizeForPagingScrollView() -> CGSize {
        return CGSize(width:  self.scrollView.bounds.size.width * CGFloat(totalPage),
                      height: self.scrollView.bounds.size.height)
    }
    
    private func contentOffsetForPageAt(index:NSInteger) -> CGPoint {
        return CGPoint(x: CGFloat(index) * self.scrollView.bounds.size.width, y: 0)
    }
    
    private func configurePageWith(index:NSInteger) {
        guard let dataSource = self.dataSource  else { return }
        guard (index >= 0 && index < totalPage) else { return }
        
        guard let page = getCurrentPageWith(index: index) else { return }
        
        dataSource.pagingScrollView(self, prepareShowPageView: page, viewForIndex: index)
        self.addPageView(page: page, index: index)
        visiblePages[String(index)] = page
    }
    
    private func getCurrentPageWith(index:NSInteger) -> UIView? {
        guard let dataSource = self.dataSource  else { return nil }
        guard (index >= 0 && index < totalPage) else { return nil }
        
        var page:UIView? = visiblePages[String(index)]
        
        guard (page == nil) else {
            return dataSource.pagingScrollView(self, recycledView: page, viewForIndex: index)
        }
        
        page = recyclePages.first
        
        guard (page == nil) else {
            recyclePages.removeFirst()
            return dataSource.pagingScrollView(self, recycledView: page, viewForIndex: index)
        }
        
        return dataSource.pagingScrollView(self, recycledView: nil, viewForIndex: index)
    }
    
    private func addPageView(page:UIView, index:NSInteger) {
        guard (index >= 0 && index < totalPage) else { return }
    
        page.tag = index
        page.frame = CGRect(x: self.contentOffsetForPageAt(index: index).x ,
                            y: 0,
                            width:  self.scrollView.bounds.width,
                            height: self.scrollView.bounds.height)
        self.scrollView.addSubview(page)
    }
    
    private func didStartViewingPageAt(index:NSInteger) {
        lockQueue.sync {
            let indexs = [index, index - 1, index + 1]
            
            indexs.forEach { self.configurePageWith(index: $0) }
            
            visiblePages.values.filter { !indexs.contains($0.tag) }.forEach { prepareRecycle(page: $0) }
            
            while recyclePages.count > recyclePageCount { recyclePages.removeLast() }
            
            self.delegate?.pagingScrollView(self, didChangedCurrentPage: self.currentPageIndex)
        }
    }
    
    private func prepareRecycle(page:UIView) {
        visiblePages.removeValue(forKey: String(page.tag) )
        recyclePages.append(page)
        page.removeFromSuperview()
    }
    
    // MARK: - uiscrollview delegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isDragging else { return }
        
        scrollView.layoutSubviews()
        
        let visibleBounds = scrollView.bounds
    
        var index = NSInteger(floor(visibleBounds.midX / visibleBounds.width))
        
        index = max(0, index)
        index = min(totalPage - 1, index)
        
        currentPageIndex = index
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.delegate?.pagingScrollView(self, willChangedCurrentPage: currentPageIndex)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        visiblePages.values.filter{ $0.tag != self.currentPageIndex }.forEach{ subPageViewLayout(view: $0) }
    }
    
    // MARK: - public methods
    
    public func jumpToPage(at index: NSInteger, animated:Bool) {
        guard (index >= 0 && index < totalPage) else { return }
        
        self.currentPageIndex = index;
        
        scrollView.setContentOffset(contentOffsetForPageAt(index: index), animated: animated)
    }
    
    public func goPreviousPage() {
        jumpToPage(at: currentPageIndex-1, animated: true)
    }
    
    public func goNextPage() {
        jumpToPage(at: currentPageIndex+1, animated: true)
    }
    
    public func reloadData() {
        scrollView.subviews.forEach { $0.removeFromSuperview() }
        visiblePages.removeAll()
        recyclePages.removeAll()
        setupTotalPage()
        setupCurrentPageIndex()
        adjustLayout()
        didStartViewingPageAt(index: currentPageIndex)
    }
    
    public func pageView(at index:NSInteger) -> UIView? {
        return visiblePages[String(index)]
    }
}