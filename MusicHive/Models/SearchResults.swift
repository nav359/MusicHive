//
//  SearchResults.swift
//  MusicHive
//
//  Created by Navdeep Paliwal on 2022/3/22.
//

import Foundation

enum SearchResults {
    case album(model: Album)
    case artist(model: Artist)
    case playlist(model: Playlist)
    case track(model: AudioTrack)
}
