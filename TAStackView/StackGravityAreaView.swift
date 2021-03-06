//
//  StackGravityAreaView.swift
//  TAStackView
//
//  Created by Tom Abraham on 8/10/14.
//  Copyright (c) 2014 Tom Abraham. All rights reserved.
//

import UIKit

class StackGravityAreaView : UIView {
  required init(coder aDecoder: NSCoder) {
    fatalError("doesn't support NSCoder")
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    // always used in manual Auto Layout context
    setTranslatesAutoresizingMaskIntoConstraints(false)
  }
  
  override convenience init() {
    self.init(frame: CGRectNull)
  }
  
// MARK: Views
  private var allViews : [UIView] = []
  
  func addView(view : UIView) {
    insertView(view, atIndex: allViews.count)
  }
  
  func insertView(view: UIView, atIndex index: Int) {
    allViews.insert(view, atIndex: index)
    view.setTranslatesAutoresizingMaskIntoConstraints(false)
    addSubview(view);
    
    let spacer = StackSpacerView()
    allSpacers.insert(spacer, atIndex: index)
    spacer.setTranslatesAutoresizingMaskIntoConstraints(false)
    addSubview(spacer)
    
    setNeedsUpdateConstraints()
  }
  
  func setViews(views : [UIView]) {
    for view in allViews { removeView(view) }
    
    for view in views { addView(view) }
  }
  
  func removeView(view : UIView) {
    let index = indexOfView(view)
    let spacer = allSpacers[index]
    
    view.removeFromSuperview()
    spacer.removeFromSuperview()
    
    setCustomSpacing(nil, afterView: view)
    allViews.removeAtIndex(index)
    allSpacers.removeAtIndex(index)
  }
  
  private func indexOfView(view : UIView) -> Int {
    for (i, v) in enumerate(allViews) {
      if (unsafeAddressOf(view) == unsafeAddressOf(v)) { return i; }
    }
    fatalError("view doesn't exist in gravity area view")
  }
  
  // TODO: add support for non-binary visibility priorities
  private func isViewAttached(view : UIView) -> Bool {
    return self.visibilityPriorityForView(view) == .MustHold
  }
  
  var views : [UIView] { return allViews }
  var attachedViews : [UIView] { return allViews.filter(isViewAttached) }
  var detachedViews : [UIView] { return allViews.filter({ !self.isViewAttached($0) }) }
  
// MARK: General
  
  var alignment : NSLayoutAttribute = DefaultAlignment {
    didSet { setNeedsUpdateConstraints() }
  }
  
  var orientation : TAUserInterfaceLayoutOrientation = DefaultOrientation {
    didSet {
      allSpacers.map({$0.orientation = self.orientation})
      
      setNeedsUpdateConstraints()
    }
  }
  
  var shouldShow : Bool { return !attachedViews.isEmpty }
  
// MARK: Spacing
  private var _customSpacingAfterView = Dictionary<UnsafePointer<Void>, Float>()

  private var allSpacers : [StackSpacerView] = []

  var attachedSpacers : [StackSpacerView] {
    // TODO: this was painful to write... cleanup
    var spacersForAttachedViews = filter(enumerate(allSpacers)) { (i, spacer) in self.isViewAttached(self.allViews[i]) }
    
    // haskell's init :'(
    if !spacersForAttachedViews.isEmpty { spacersForAttachedViews.removeLast() }
    
    // ...and unzip
    return spacersForAttachedViews.map({ $0.element })
  }
  
  var spacingAfter : Float { assert(!attachedViews.isEmpty); return spacingAfterView(attachedViews.last!) }
  
  private func spacingAfterView(view : UIView) -> Float {
    return hasEqualSpacing ? spacing : (customSpacingAfterView(view) ?? spacing)
  }
  
  func setCustomSpacing(spacing: Float?, afterView view: UIView) {
    _customSpacingAfterView[unsafeAddressOf(view)] = spacing
    
    setNeedsUpdateConstraints()
  }
  
  func customSpacingAfterView(view : UIView) -> Float? {
    return _customSpacingAfterView[unsafeAddressOf(view)]
  }

  var spacing : Float = DefaultSpacing {
    didSet { setNeedsUpdateConstraints() }
  }
  
  var hasEqualSpacing : Bool = false {
    didSet { setNeedsUpdateConstraints() }
  }

// MARK: Priorities
  private var _visibilityPriorityForView = Dictionary<UnsafePointer<Void>, StackViewVisibilityPriority>()
  
  private var horizontalClippingResistancePriority = DefaultClippingResistancePriority
  private var verticalClippingResistancePriority = DefaultClippingResistancePriority
  private var horizontalHuggingPriority = DefaultHuggingPriority
  private var verticalHuggingPriority = DefaultHuggingPriority
  
  func setClippingResistancePriority(priority : UILayoutPriority, forAxis axis : UILayoutConstraintAxis) {
    if (axis == .Horizontal) {
      horizontalClippingResistancePriority = priority
    } else {
      verticalClippingResistancePriority = priority
    }
  }
  
  func clippingResistancePriorityForAxis(axis : UILayoutConstraintAxis) -> UILayoutPriority {
    return axis == .Horizontal ? horizontalClippingResistancePriority : verticalClippingResistancePriority
  }

  func setHuggingPriority(priority : UILayoutPriority, forAxis axis : UILayoutConstraintAxis) {
    if (axis == .Horizontal) {
      horizontalHuggingPriority = priority
    } else {
      verticalHuggingPriority = priority
    }
  }
  
  func huggingPriorityForAxis(axis : UILayoutConstraintAxis) -> UILayoutPriority {
    return axis == .Horizontal ? horizontalHuggingPriority : verticalHuggingPriority
  }
  
  func setVisibilityPriority(visibilityPriority : StackViewVisibilityPriority, forView view : UIView) {
    assert(visibilityPriority == .MustHold || visibilityPriority == .NotVisible, "only support binary visibility priority for now")
    
    _visibilityPriorityForView[unsafeAddressOf(view)] = visibilityPriority
    
    setNeedsUpdateConstraints()
  }
  
  func visibilityPriorityForView(view : UIView) -> StackViewVisibilityPriority {
    return _visibilityPriorityForView[unsafeAddressOf(view)] ?? .MustHold
  }

// MARK: Layout

  override func updateConstraints() {
    hidden = attachedViews.isEmpty

    func _mainConstraints() -> [NSLayoutConstraint] {
      let otherAxis = orientation.other().toAxis();
      let metrics = [ "Hp_other": huggingPriorityForAxis(otherAxis) ]

      let char = orientation.toCharacter()
      let otherChar = orientation.other().toCharacter()

      var cs : [NSLayoutConstraint] = []
      for (i, view) in enumerate(attachedViews) {
        var map = [ "view" : view, "spacer" : allSpacers[i] ]
        var vfls : [String] = []

        // VFL for axis:
        // e.g. if the stack view was horizontally oriented in LTR (left-to-right) configuration,
        //  1) stack views horizontally, one after the other
        //  2) place spacer between every pair of views
        //  3) pin first view to left, last view to right
        if (i == 0) {
          vfls += [ "\(char):|[view]" ];
        }

        if (i == attachedViews.count - 1) {
          vfls += [ "\(char):[view]|" ]
        } else {
          map["nextView"] = attachedViews[i + 1];
          vfls += [ "\(char):[view][spacer][nextView]" ];
        }

        // VFL for otherAxis:
        // e.g. if the stack view was horizontally oriented,
        //  1) make sure all views fit vertically
        //  2) make sure stack view hugs each view vertically with the vertical hugging priority
        vfls += [ "\(otherChar):|-(>=0,0@Hp_other)-[view]", "\(otherChar):[view]-(>=0,0@Hp_other)-|" ]

        cs += NSLayoutConstraint.constraintsWithVisualFormats(vfls, options: NSLayoutFormatOptions(0), metrics: metrics, views: map)
      }
      return cs
    }

    func _alignmentConstraints() -> [NSLayoutConstraint] {
      return attachedViews.map({ (view : UIView) -> NSLayoutConstraint in
        NSLayoutConstraint(
          item: self, attribute: self.alignment,
          relatedBy: .Equal,
          toItem: view, attribute: self.alignment,
          multiplier: 1.0, constant: 0.0
        )
      })
    }
    
    func _updateInterViewSpacing() {
      if (allViews.count == 0) { return }
      
      for i in 0 ..< allViews.count - 1 {
        let view = allViews[i]
        let spacer = allSpacers[i]
        
        let hP = huggingPriorityForAxis(orientation.toAxis())
        
        spacer.spacing = spacingAfterView(view)
        spacer.spacingPriority = hasEqualSpacing ? hP : max(LayoutPriorityDefaultHigh, hP)
        spacer.orientation = orientation
      }
    }
    
    func _updateViewVisibility() {
      allViews.map({ $0.hidden = self.visibilityPriorityForView($0) != .MustHold })
    }

    self.removeConstraints(constraints())
    self.addConstraints(_mainConstraints())
    self.addConstraints(_alignmentConstraints())
    
    _updateInterViewSpacing()
    _updateViewVisibility()
    
    super.updateConstraints()
  }
}