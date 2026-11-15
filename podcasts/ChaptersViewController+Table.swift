import Foundation
import SafariServices
import PocketCastsUtils

extension ChaptersViewController: UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {
    private static let chapterCell = "ChapterCell"

    func registerCells() {
        chaptersTable.register(UINib(nibName: "PlayerChapterCell", bundle: nil), forCellReuseIdentifier: ChaptersViewController.chapterCell)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollViewHandler?.scrollViewDidScroll?(scrollView)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        PlaybackManager.shared.chapterCount(onlyPlayable: !isTogglingChapters)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let chapterCell = tableView.dequeueReusableCell(withIdentifier: ChaptersViewController.chapterCell, for: indexPath) as! PlayerChapterCell

        if let chapter = isTogglingChapters ? PlaybackManager.shared.chapterAt(index: indexPath.row) : PlaybackManager.shared.playableChapterAt(index: indexPath.row) {
            var state = PlayerChapterCell.ChapterPlayState.played
            let currentChapters = PlaybackManager.shared.currentChapters

            if chapter.index == currentChapters.index {
                state = PlaybackManager.shared.isPlaying ? .currentlyPlaying : .currentlyPaused
            } else if chapter.index > currentChapters.index {
                state = .future
            }

            chapterCell.populateFrom(chapter: chapter, playState: state, isChapterToggleEnabled: isTogglingChapters) { [weak self] url in
                if Settings.openLinks {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    self?.present(SFSafariViewController(with: url), animated: true)
                }
            }

            chapterCell.seperatorView.isHidden = (chapter.index == PlaybackManager.shared.currentChapters.index - 1 || chapter.index == PlaybackManager.shared.currentChapters.index || (indexPath.row == PlaybackManager.shared.chapterCount() - 1))
        }


        return chapterCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard !isTogglingChapters else {
            // Ensure at least one chapter is selected
            if PlaybackManager.shared.chapterAt(index: indexPath.row)?.isPlayable() == true, PlaybackManager.shared.chapterCount(onlyPlayable: true) == 1 {
                Toast.show(L10n.selectAChapter)
                return
            }

            (tableView.cellForRow(at: indexPath) as? PlayerChapterCell)?.toggleChapterTapped(self)
            return
        }

        if let chapter = PlaybackManager.shared.playableChapterAt(index: indexPath.row) {
            if chapter.index == PlaybackManager.shared.currentChapters.index {
                containerDelegate?.scrollToNowPlaying()
                // Android also emits the selection event when the tapped chapter is
                // already playing, so keep parity even though nothing seeks here.
            } else {
                PlaybackManager.shared.skipToChapter(chapter, startPlaybackAfterSkip: true)
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    var shouldShowDeselectChaptersHeader: Bool {
        PlaybackManager.shared.currentEpisode?.isUserEpisode == false
    }
}

extension ChaptersViewController: ChaptersHeaderDelegate {
    func toggleTapped() {
        isTogglingChapters.toggle()
        chaptersTable.reloadSections([0], with: .automatic)
        header.isTogglingChapters = isTogglingChapters
        header.update()
        updateSize()
        playbackManager.playableChaptersUpdated()

        if isTogglingChapters {
            numberOfDeselectedChapters = playbackManager.chapterCount(onlyPlayable: true)
        } else {
            numberOfDeselectedChapters -= playbackManager.chapterCount(onlyPlayable: true)
        }
    }
}
