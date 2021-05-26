//
//  Authenticator.swift
//  Comet
//
//  Created by Tuan Tu Do on 26.05.2021.
//  Copyright © 2021 Etnetera. All rights reserved.
//

import Combine
import Foundation

final class Authenticator {
    private let tokenProvider: TokenProviding
    private let queue = DispatchQueue(label: "Authenticator-\(UUID().uuidString)")
    private var refreshTokenPublisher: AnyPublisher<String, AuthenticatorError>?

    init(tokenProvider: TokenProviding) {
        self.tokenProvider = tokenProvider
    }

    var token: AnyPublisher<String, AuthenticatorError> {
        queue.sync { [weak self] in
            guard let unwrappedSelf = self else {
                return Fail(error: AuthenticatorError.internalError).eraseToAnyPublisher()
            }

            if let publisher = unwrappedSelf.refreshTokenPublisher {
                return publisher
            }

            return unwrappedSelf.tokenProvider.accessToken
                .mapError { _ in AuthenticatorError.noValidToken }
                .eraseToAnyPublisher()
        }
    }

    var refreshedToken: AnyPublisher<String, AuthenticatorError> {
        queue.sync { [weak self] in
            guard let unwrappedSelf = self else {
                return Fail(error: AuthenticatorError.internalError).eraseToAnyPublisher()
            }

            if let publisher = unwrappedSelf.refreshTokenPublisher {
                return publisher
            }

            let publisher = unwrappedSelf.tokenProvider.refreshAccessToken
                .mapError { _ in AuthenticatorError.noValidToken }
                .handleEvents(receiveCompletion: { _ in
                    unwrappedSelf.refreshTokenPublisher = nil
                })
                .share()
                .eraseToAnyPublisher()

            unwrappedSelf.refreshTokenPublisher = publisher

            return publisher
        }
    }
}

fileprivate extension TokenProvidingError {
    var authenticatorError: AuthenticatorError {
        switch self {
        case .noToken:
            return .noValidToken
        case .invalidToken:
            return .noValidToken
        case .loginRequired:
            return .loginRequired
        case .internalServerError:
            return .internalServerError
        case .httpError(let code):
            return .httpError(code: code)
        }
    }
}

