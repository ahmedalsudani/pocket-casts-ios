import UIKit

extension PlaylistDetailViewController: UISheetPresentationControllerDelegate, PlaylistPlayAllSheetHostDelegate {
    func playAll() {
        if viewModel.episodes.isEmpty {
            Toast.show(L10n.playlistManualPlayAllEmptyList)
            return
        }

        let playlistEpisodeIDs = viewModel.episodes.map { $0.episode.uuid }
        if !PlaybackManager.shared.playIfSafe(playlist: viewModel.playlist, episodeIDs: playlistEpisodeIDs) {
            let sheet = PlaylistPlayAllSheetHost(delegate: self)
            present(sheet, animated: true)
        }
    }

    func onTapSaveAndReplace() {
        presentedViewController?.dismiss(animated: true)

        if Settings.saveCurrentUpNextQueueIntoPlaylist {
            viewModel.saveUpNextAndPlay()
            return
        }

        viewModel.playAllEpisodes()
    }
}
