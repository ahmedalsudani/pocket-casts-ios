import Foundation
import PocketCastsDataModel
import PocketCastsUtils

/// Cloud file storage lived on the Pocket Casts API. In this local-only build
/// files never leave the device, so every endpoint completes immediately
/// without queueing a network operation. The methods stay so remaining call
/// sites (and the watch target) keep compiling.
public extension ApiServerHandler {
    func retrieveCustomFilesTask() {
    }

    func uploadFileRequest(episode: UserEpisode, completion: @escaping (URL?) -> Void) {
        completion(nil)
    }

    func uploadImageRequest(episode: UserEpisode, completion: @escaping (URL?) -> Void) {
        completion(nil)
    }

    func uploadFileDelete(episode: UserEpisode, completion: @escaping (Bool?) -> Void) {
        completion(false)
    }

    func uploadFilePlayRequest(episode: UserEpisode, completion: @escaping (URL?) -> Void) {
        completion(nil)
    }

    func uploadFilesUpdateRequest(episodes: [UserEpisode], completion: @escaping (Int) -> Void) {
        completion(0)
    }

    func uploadSingleFileUpdateRequest(episode: UserEpisode, completion: @escaping (Int) -> Void) {
        completion(0)
    }

    func uploadFilesUpdateStatusRequest(episode: UserEpisode) {
    }

    func uploadImageDelete(episode: UserEpisode, completion: @escaping (Bool?) -> Void) {
        completion(false)
    }

    func uploadFileUsageRequest() {
    }
}
