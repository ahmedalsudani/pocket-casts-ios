import Foundation
import PocketCastsDataModel
import PocketCastsUtils
import PocketCastsServer
import Combine

extension DownloadManager {
    func logDownload(_ episode: BaseEpisode, failure: FailureReason, metrics: URLSessionTaskMetrics, session: URLSession) {
        let errorCode: Int?
        let errorDomain: String?
        if case let DownloadManager.FailureReason.unknown(error) = failure {
            errorCode = error.code
            errorDomain = error.domain
        } else {
            errorCode = nil
            errorDomain = nil
        }

        let statusCode: Int?
        if case let DownloadManager.FailureReason.statusCode(code) = failure {
            statusCode = code
        } else {
            statusCode = metrics.transactionMetrics.last?.response?.extractStatusCode()
        }

        let isProxy = metrics.transactionMetrics.last?.isProxyConnection == true
        let isCellular = metrics.transactionMetrics.last?.isCellular == true

        let url = metrics.transactionMetrics.last?.request.url?.absoluteString ?? "unknown"
        FileLog.shared.addMessage("DownloadManager: Failed download \(episode.uuid) \(url) statusCode:\(String(describing: statusCode)) isCell:\(isCellular) isProxy: \(isProxy) errorCode:\(String(describing: errorCode)) errorDomain:\(String(describing: errorDomain))")
    }
}
