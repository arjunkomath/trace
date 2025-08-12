//
//  ResultEventPublisher.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation
import Combine

enum ResultUpdateEvent {
    case loading(commandId: String)
    case completed(commandId: String, newTitle: String, newSubtitle: String, accessory: SearchResultAccessory?)
    case failed(commandId: String, error: String)
}

class ResultEventPublisher: ObservableObject {
    private let eventSubject = PassthroughSubject<ResultUpdateEvent, Never>()
    
    var events: AnyPublisher<ResultUpdateEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    func publishUpdate(_ event: ResultUpdateEvent) {
        eventSubject.send(event)
    }
}