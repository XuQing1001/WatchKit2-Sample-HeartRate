//
//  InterfaceController.swift
//  WatchKit2-Sample-HeartRate WatchKit Extension
//
//  Created by XuQing on 15/8/4.
//  Copyright © 2015年 XuQing1001. All rights reserved.
//

import Foundation
import HealthKit
import WatchKit

class HeartRateInterfaceController: WKInterfaceController, HKWorkoutSessionDelegate {
    
    // 标签：状态
    @IBOutlet private weak var statusLabel: WKInterfaceLabel!
    // 标签：心跳数
    @IBOutlet private weak var heartRateLabel: WKInterfaceLabel!
    
    let healthStore = HKHealthStore()
    
    // 定义锻炼类型和地点
    let workoutSession = HKWorkoutSession(activityType: HKWorkoutActivityType.Play, locationType: HKWorkoutSessionLocationType.Indoor)
    let heartRateUnit = HKUnit(fromString: "count/min")
    
    // 初始锚点 / 初次查询后该变量用于存储新锚点信息
    var anchor = HKQueryAnchor(fromValue: Int(HKAnchoredObjectQueryNoAnchor))
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        workoutSession.delegate = self
    }
    
    override func willActivate() {
        super.willActivate()
        
        guard HKHealthStore.isHealthDataAvailable() == true else {
            self.updateStatus("数据不可用")
            return
        }
    
        guard let quantityType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate) else {
            self.updateStatus("需要权限")
            return
        }
        
        let dataTypes = Set(arrayLiteral: quantityType)
        healthStore.requestAuthorizationToShareTypes(nil, readTypes: dataTypes) { (success, error) -> Void in
            if success == false {
                self.updateStatus("需要权限")
            }
        }
    }
    
    // 更新状态标签文字
    func updateStatus(statusText: String) {
        statusLabel.setText(statusText)
    }
    
    func workoutSession(workoutSession: HKWorkoutSession, didChangeToState toState: HKWorkoutSessionState, fromState: HKWorkoutSessionState, date: NSDate) {
        switch toState {
        case .Running:
            workoutDidStart(date)
        case .Ended:
            workoutDidEnd(date)
        default:
            print("异常状态 \(toState)")
        }
    }
    
    func workoutSession(workoutSession: HKWorkoutSession, didFailWithError error: NSError) {
        // ...
    }
    
    // 锻炼开始时开始记录心跳
    func workoutDidStart(date : NSDate) {
        if let query = createHeartRateStreamingQuery(date) {
            healthStore.executeQuery(query)
            self.updateStatus("正在检测...")
        } else {
            self.updateStatus("启动失败")
        }
    }
    
    // 锻炼结束时停止记录心跳
    func workoutDidEnd(date : NSDate) {
        if let query = createHeartRateStreamingQuery(date) {
            healthStore.stopQuery(query)
            heartRateLabel.setText("--")
            self.updateStatus("已停止")
        } else {
            self.updateStatus("停止失败")
        }
    }
    
    // Action: 开始按钮
    @IBAction func startBtnTapped() {
        // 开始锻炼
        healthStore.startWorkoutSession(workoutSession)
    }
    // Action: 停止按钮
    @IBAction func stopBtnTapped() {
        // 结束锻炼
        healthStore.endWorkoutSession(workoutSession)
    }
    
    // 创建查询的实例对象
    func createHeartRateStreamingQuery(workoutStartDate: NSDate) -> HKQuery? {
        /* 
           下面将创建一个锚点查询（Anchored object query）的实例对象
           使用这种查询方法，第一次查询会返回所有匹配项。 
           从第二次查询开始，只会返回前一次查询后新增的项目。
        */

        // 得到心跳数据的样本类型
        guard let quantityType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate) else { return nil }
        
        // 创建锚点查询（HKAnchoredObjectQuery）的实例
        let heartRateQuery = HKAnchoredObjectQuery(type: quantityType, predicate: nil, anchor: anchor, limit: Int(HKObjectQueryNoLimit)) { (query, samples, deletedObjects, newAnchor, error) -> Void in
            guard let newAnchor = newAnchor else {return}
            self.anchor = newAnchor
            self.updateUI(samples)// 更新视图
        }
        
        // 配置锚点查询的updateHandler，监视样本变化。样本变化时自动执行代码块内容
        heartRateQuery.updateHandler = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            self.anchor = newAnchor!
            self.updateUI(samples)// 更新视图
        }
        
        // 返回查询的实例对象
        return heartRateQuery
    }
    
    // 更新心跳数字
    func updateUI(samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else {return}
        dispatch_async(dispatch_get_main_queue()) {
            guard let sample = heartRateSamples.first else{return}
            let value = sample.quantity.doubleValueForUnit(self.heartRateUnit)
            self.heartRateLabel.setText(String(UInt16(value)))
        }
    }
}
