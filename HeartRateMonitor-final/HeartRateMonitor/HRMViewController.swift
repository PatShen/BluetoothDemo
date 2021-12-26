/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import CoreBluetooth
import SnapKit

let DeviceChangedNotification: Notification.Name = .init(rawValue: "DeviceChangedNotification")

let heartRateServiceCBUUID = CBUUID(string: "3802")
let heartRateMeasurementCharacteristicCBUUID = CBUUID(string: "2A37")
let bodySensorLocationCharacteristicCBUUID = CBUUID(string: "2A38")
let huaweiSCUUID = CBUUID(string: "4A02")

class HRMViewController: UIViewController {

  @IBOutlet weak var heartRateLabel: UILabel!
  @IBOutlet weak var bodySensorLocationLabel: UILabel!
  
  private let uuidKey = "connectedUUID"

  var centralManager: CBCentralManager!
  var heartRatePeripheral: CBPeripheral? {
    didSet {
      self.bluetoothInfo = ""
    }
  }
  
  private lazy var txtvContent: UITextView = {
    let txtv = UITextView()
    txtv.isEditable = false
    return txtv
  }()
  
  private var peripherals: [CBPeripheral] = []
  
  private var bluetoothInfo: String = "" {
    didSet {
      self.txtvContent.text = self.bluetoothInfo
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    centralManager = CBCentralManager(delegate: self, queue: nil)
//    let ud = UserDefaults.standard
//    if let id = ud.value(forKey: self.uuidKey) as? UUID {
//      let uuid = CBUUID.init(nsuuid: id)
//      let array = centralManager.retrieveConnectedPeripherals(withServices: [heartRateServiceCBUUID])
//      for sub in array {
//        self.__update(peripheral: sub)
//      }
//    }

    // Make the digits monospaces to avoid shifting when the numbers change
//    heartRateLabel.font = UIFont.monospacedDigitSystemFont(ofSize: heartRateLabel.font!.pointSize, weight: .regular)
    
    self.view.addSubview(self.txtvContent)
    txtvContent.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    
    let item = UIBarButtonItem.init(barButtonSystemItem: .bookmarks, target: self, action: #selector(__goDeviceList))
    self.navigationItem.rightBarButtonItem = item
  }

  func onHeartRateReceived(_ heartRate: Int) {
    heartRateLabel.text = String(heartRate)
    print("BPM: \(heartRate)")
  }
}

private extension HRMViewController {
  @objc func __goDeviceList() {
    let vc = DeviceListViewController()
    vc.update(peripherals: self.peripherals)
    vc.touchedClosure = { [weak self] idx in
      self?.__touchedPeripheral(at: idx)
    }
    let nav = UINavigationController.init(rootViewController: vc)
    
    self.present(nav, animated: true, completion: nil)
  }
  
  func __update(peripheral: CBPeripheral) {
    if let idx = self.peripherals.firstIndex(where: { $0.identifier == peripheral.identifier }) {
      self.peripherals[idx] = peripheral
    } else {
      if let _ = peripheral.name {
        self.peripherals.append(peripheral)
      } else {
        return
      }
    }
    
    let center = NotificationCenter.default
    center.post(name: DeviceChangedNotification, object: nil, userInfo: ["array" : self.peripherals])
  }
  
  func __touchedPeripheral(at index: Int) {
    let p = self.peripherals[index]
    switch p.state {
    case .disconnected:
      self.__connect(peripheral: p)
    case .connected:
      self.centralManager.cancelPeripheralConnection(p)
      self.heartRatePeripheral = nil
    case .connecting, .disconnecting:
      break
    }
  }
  
  func __connect(peripheral: CBPeripheral) {
    peripheral.delegate = self
    self.centralManager.connect(peripheral, options: nil)
    self.heartRatePeripheral = peripheral
  }
}

extension HRMViewController: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .unknown:
      print("central.state is .unknown")
    case .resetting:
      print("central.state is .resetting")
    case .unsupported:
      print("central.state is .unsupported")
    case .unauthorized:
      print("central.state is .unauthorized")
    case .poweredOff:
      print("central.state is .poweredOff")
    case .poweredOn:
      print("central.state is .poweredOn")
      
      centralManager.scanForPeripherals(withServices: [heartRateServiceCBUUID], options: nil)
      let array = centralManager.retrieveConnectedPeripherals(withServices: [heartRateServiceCBUUID])
      if let p = array.first {
        self.__update(peripheral: p)
        self.__connect(peripheral: p)
      }
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                      advertisementData: [String : Any], rssi RSSI: NSNumber) {
    print("start-------")
    print(peripheral.identifier)
    print(advertisementData)
    print(RSSI)
    print("end-------")
    self.__update(peripheral: peripheral)
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("Connected!")
    self.heartRatePeripheral?.discoverServices([heartRateServiceCBUUID])
  }
  
  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
    
  }
}

extension HRMViewController: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let services = peripheral.services else { return }
    for service in services {
      print(service)
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard let characteristics = service.characteristics else { return }

    for characteristic in characteristics {
      print(characteristic)

      if characteristic.properties.contains(.read) {
        print("\(characteristic.uuid): properties contains .read")
        peripheral.readValue(for: characteristic)
      }
      if characteristic.properties.contains(.notify) {
        print("\(characteristic.uuid): properties contains .notify")
        peripheral.setNotifyValue(true, for: characteristic)
      }
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    switch characteristic.uuid {
    case bodySensorLocationCharacteristicCBUUID:
      let bodySensorLocation = bodyLocation(from: characteristic)
//      bodySensorLocationLabel.text = bodySensorLocation
      self.bluetoothInfo.append("BodySensorLocation: \(bodySensorLocation)\n")
    case heartRateMeasurementCharacteristicCBUUID:
      let bpm = heartRate(from: characteristic)
//      onHeartRateReceived(bpm)
      self.bluetoothInfo.append("BPM: \(bpm)\n")
    case huaweiSCUUID:
      var text: String = "Unhandled Characteristic UUID: \(characteristic.uuid)"
      if let s = characteristic.service {
        text.append(" serviceUUID: \(s.uuid)\n")
      }
      self.bluetoothInfo.append(text)
    default:
      var text: String = "Unhandled Characteristic UUID: \(characteristic.uuid)"
      if let s = characteristic.service {
        text.append(" serviceUUID: \(s.uuid)\n")
      }
      self.bluetoothInfo.append(text)
    }
  }

  private func bodyLocation(from characteristic: CBCharacteristic) -> String {
    guard let characteristicData = characteristic.value,
      let byte = characteristicData.first else { return "Error" }

    switch byte {
    case 0: return "Other"
    case 1: return "Chest"
    case 2: return "Wrist"
    case 3: return "Finger"
    case 4: return "Hand"
    case 5: return "Ear Lobe"
    case 6: return "Foot"
    default:
      return "Reserved for future use"
    }
  }

  private func heartRate(from characteristic: CBCharacteristic) -> Int {
    guard let characteristicData = characteristic.value else { return -1 }
    let byteArray = [UInt8](characteristicData)

    // See: https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.heart_rate_measurement.xml
    // The heart rate mesurement is in the 2nd, or in the 2nd and 3rd bytes, i.e. one one or in two bytes
    // The first byte of the first bit specifies the length of the heart rate data, 0 == 1 byte, 1 == 2 bytes
    let firstBitValue = byteArray[0] & 0x01
    if firstBitValue == 0 {
      // Heart Rate Value Format is in the 2nd byte
      return Int(byteArray[1])
    } else {
      // Heart Rate Value Format is in the 2nd and 3rd bytes
      return (Int(byteArray[1]) << 8) + Int(byteArray[2])
    }
  }
}
