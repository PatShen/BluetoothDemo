/// Copyright (c) 2021 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation
import UIKit
import CoreBluetooth
import SnapKit
import SwifterSwift

class DeviceListViewController: UIViewController {
  
  deinit {
    self.__removeOB()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.__configUI()
    self.__addOB()
  }
  
  private var peripherals: [CBPeripheral] = []
  
  private lazy var tblList: UITableView = {
    let tbl = UITableView()
    tbl.dataSource = self
    tbl.delegate = self
    tbl.tableFooterView = UIView()
    tbl.register(cellWithClass: PeripheralCell.self)
    return tbl
  }()
  
  private var __touchedClosure: ((Int) -> Void)?
}

// MARK: 内部调用
private extension DeviceListViewController {
  func __configUI() {
    self.title = "发现设备"
    self.view.addSubview(self.tblList)
    tblList.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    
    let back = UIBarButtonItem.init(barButtonSystemItem: .cancel, target: self, action: #selector(__cancelHandler))
    self.navigationItem.leftBarButtonItem = back
  }
  
  @objc func __cancelHandler() {
    self.dismiss(animated: true, completion: nil)
  }
  
  func __addOB() {
    let center = NotificationCenter.default
    center.addObserver(self, selector: #selector(__peripheralsHandler(_:)), name: DeviceChangedNotification, object: nil)
  }
  func __removeOB() {
    let center = NotificationCenter.default
    center.removeObserver(self)
  }
  
  @objc func __peripheralsHandler(_ notification: Notification) {
    if let array = notification.userInfo?["array"] as? [CBPeripheral] {
      self.__update(peripherals: array)
    }
  }
  
  @objc func __update(peripherals: [CBPeripheral]) {
    self.peripherals = peripherals
    self.tblList.reloadData()
  }
}

extension DeviceListViewController {
  func update(peripherals: [CBPeripheral]) {
    self.__update(peripherals: peripherals)
  }
  
  var touchedClosure: ((Int) -> Void)? {
    get { __touchedClosure }
    set { __touchedClosure = newValue }
  }
}

// MARK: UITablView 协议
extension DeviceListViewController: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.peripherals.count
  }
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withClass: PeripheralCell.self)
    
    let p = self.peripherals[indexPath.row]
    if let name = p.name {
      cell.lblTitle.text = name
    } else {
      cell.lblTitle.text = "未命名设备"
    }
    cell.lblID.text = p.identifier.uuidString
    var stateText: String = ""
    switch p.state {
    case .disconnected:
      stateText = "未连接"
    case .connecting:
      stateText = "正在连接"
    case .connected:
      stateText = "已连接"
    case .disconnecting:
      stateText = "正在断开连接"
    }
    cell.lblStatus.text = stateText
    return cell
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return UITableViewAutomaticDimension
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    self.touchedClosure?(indexPath.row)
    DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
      self.__cancelHandler()
    }
  }
}

// MARK: - 外设Cell
fileprivate class PeripheralCell: UITableViewCell {
  override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    self.__installConstraints()
  }
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func __installConstraints() {
    self.contentView.addSubview(self.lblTitle)
    self.contentView.addSubview(self.lblID)
    self.contentView.addSubview(self.lblStatus)
    
    lblTitle.snp.makeConstraints { make in
      make.top.equalToSuperview().offset(8.0)
      make.leading.equalToSuperview().offset(8.0)
      make.trailing.lessThanOrEqualTo(self.lblStatus.snp.leading).offset(-8.0)
    }
    lblID.snp.makeConstraints { make in
      make.top.equalTo(self.lblTitle.snp.bottom).offset(4.0)
      make.leading.equalToSuperview().offset(8.0)
      make.trailing.lessThanOrEqualTo(self.lblStatus.snp.leading).offset(-8.0)
      make.bottom.equalToSuperview().offset(-8.0).priority(.high)
    }
    
    lblStatus.snp.makeConstraints { make in
      make.centerY.equalToSuperview()
      make.trailing.equalToSuperview().offset(-8.0)
    }
  }
  
  private (set) lazy var lblTitle: UILabel = {
    let lbl = UILabel()
    return lbl
  }()
  
  private (set) lazy var lblID: UILabel = {
    let lbl = UILabel()
    lbl.font = UIFont.systemFont(ofSize: 15.0)
    if #available(iOS 13.0, *) {
      lbl.textColor = UIColor.init(light: .gray, dark: .lightGray)
    } else {
      // Fallback on earlier versions
      lbl.textColor = UIColor.gray
    }
    return lbl
  }()
  
  private (set) lazy var lblStatus: UILabel = {
    let lbl = UILabel()
    if #available(iOS 13.0, *) {
      lbl.textColor = UIColor.init(light: .gray, dark: .lightGray)
    } else {
      // Fallback on earlier versions
      lbl.textColor = UIColor.gray
    }
    return lbl
  }()
}
