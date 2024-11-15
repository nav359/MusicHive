//
//  ViewController.swift
//  MusicHive
//
//  Created by Navdeep Paliwal on 2022/3/10.
//

import UIKit

enum BrowseSectionType {
    case newReleases(viewModel:  [NewReleaseCellViewModel]) //1
    case featuredPlaylist(viewModel:  [FeaturedPlaylistCellViewModel]) //2
    case recommendedTracks(viewModel:  [RecommendedTrackCellViewModel]) //3
    
    //Computed property
    var title: String {
        switch self {
        case .newReleases:
            return "New Released Album"
        case .featuredPlaylist:
            return "Featured Playlist"
        case .recommendedTracks:
            return "Just for You"
        }
    }
}
class HomeViewController: UIViewController {
    
    private var newAlbums: [Album] = []
    private var playlists: [Playlist] = []
    private var tracks: [AudioTrack] = []
    
    private var collectionView: UICollectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: UICollectionViewCompositionalLayout { sectionIndex, _ -> NSCollectionLayoutSection? in
            return HomeViewController.createSectionLayout(section: sectionIndex)
        }
    )
    
    private let spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView()
        spinner.tintColor = .label
        spinner.hidesWhenStopped = true
        
        return spinner
    }()
    
    private var sections = [BrowseSectionType]()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Browse"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gear"),
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(didTapSettings))
        
        configureCollectionView()
        view.addSubview(spinner)
        fetchData()
        addLongGesture()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.frame = view.bounds
        
    }
    private func addLongGesture() {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressed(_:)))
        collectionView.isUserInteractionEnabled = true
        collectionView.addGestureRecognizer(gesture)
    }
    @objc func didLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else {
            return
        }
        
        let touchPoint = gesture.location(in: collectionView)
        print("Poing \(touchPoint)")
        guard let indexPath = collectionView.indexPathForItem(at: touchPoint),
              indexPath.section == 2 else {
            return
        }
        
        let model = tracks[indexPath.row]
        
        let actionSheet = UIAlertController(title: model.name, message: "Would you like to add this to a playlist", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        actionSheet.addAction(UIAlertAction(title: "Add to Playlist", style: .default, handler: {[weak self] _ in
            DispatchQueue.main.async {
                let vc = LibraryPlaylistViewController()
                vc.selectionHandler = { playlist in
                    APICaller.shared.addTrackToPlaylist(track: model, playlist: playlist) { success in
                        if success {
                            print("Item has been added to Playlist")
                        }
                    }
                }
                vc.title = "Select Playlist"
                self?.present(UINavigationController(rootViewController: vc), animated: true)
            }
        }))
        present(actionSheet, animated: true)
    }
    private func configureCollectionView() {
        view.addSubview(collectionView)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.register(NewReleaseCollectionViewCell.self, forCellWithReuseIdentifier: NewReleaseCollectionViewCell.identifier)
        collectionView.register(FeaturedPlaylistCollectionViewCell.self, forCellWithReuseIdentifier: FeaturedPlaylistCollectionViewCell.identifier)
        collectionView.register(RecommendedTrackCollectionViewCell.self, forCellWithReuseIdentifier: RecommendedTrackCollectionViewCell.identifier)
       
        collectionView.register(TitleHeaderCollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: TitleHeaderCollectionReusableView.identifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .systemBackground
    }
    
    
    private func fetchData() {
        let group = DispatchGroup()
        group.enter()
        group.enter()
        group.enter()
        var newReleases: NewReleasesModel?
        var featurePlaylist: FeaturedPlaylistModel?
        var recommendations: RecommendationsModel?
        // New Releases
        APICaller.shared.getNewReleases { result in
            defer {
                group.leave()
            }
            switch result {
            case .success(let model):
                newReleases = model
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        // Featured Playlist,
        APICaller.shared.getFeaturedPlaylist { result in
            defer {
                group.leave()
            }
            switch result {
            case .success(let model):
                featurePlaylist = model
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        // Recommended Tracks,
        APICaller.shared.getRecommedationGenre { result in
            switch result {
            case .success(let model):
                let genres = model.genres
                var seeds = Set<String>()
                while seeds.count < 5 {
                    if let random = genres.randomElement() {
                        seeds.insert(random)
                    }
                }
                APICaller.shared.getRecommendations(genres: seeds) { recommendedResult in
                    defer {
                        group.leave()
                    }
                    switch recommendedResult {
                    case .success(let model):
                        recommendations = model
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        
        group.notify(queue: .main) {
            guard let newAlbums = newReleases?.albums.items,
                  let playlists = featurePlaylist?.playlists.items,
                  let tracks = recommendations?.tracks else {
                      fatalError("Models are nil ")
                      return
                  }
            self.configureModels(newAlbums: newAlbums, playlists: playlists, tracks: tracks)
            
        }
        
        
    }
    
    
    private func configureModels(
        newAlbums: [Album],
        playlists: [Playlist],
        tracks: [AudioTrack]) {
            
            self.newAlbums = newAlbums
            self.playlists = playlists
            self.tracks = tracks
            
            //Configure View models
            sections.append(.newReleases(viewModel: newAlbums.compactMap({
                return NewReleaseCellViewModel(name: $0.name, artworkURL: URL(string: $0.images.first?.url ?? ""), numberOfTracks: $0.total_tracks, artistName: $0.artists.first?.name ?? "-")
            })))
            sections.append(.featuredPlaylist(viewModel: playlists.compactMap({
                return FeaturedPlaylistCellViewModel(name: $0.name, artworkURL: URL(string: $0.images.first?.url ?? ""), creatorName: $0.owner.display_name)
            })))
            sections.append(.recommendedTracks(viewModel: tracks.compactMap({
                return RecommendedTrackCellViewModel(name: $0.name, artistName: $0.artists.first?.name ?? "_", artworkURL: URL(string: $0.album?.images.first?.url ?? ""))
            })))
            collectionView.reloadData()
        }
    @objc func didTapSettings() {
        let vc = SettingsViewController()
        vc.title = "Settings"
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }
}


extension HomeViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let type = sections[section]
        switch type {
        case .newReleases(let viewModels):
            return viewModels.count
        case .featuredPlaylist(let viewModels):
            return viewModels.count
        case .recommendedTracks(let viewModels):
            return viewModels.count
        }
        
    }
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let type = sections[indexPath.section]
        switch type {
        case .newReleases(let viewModels):
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NewReleaseCollectionViewCell.identifier, for:  indexPath) as? NewReleaseCollectionViewCell else {
                return UICollectionViewCell()
            }
            let viewModel = viewModels[indexPath.row]
            cell.configure(with: viewModel)
            return cell
        case .featuredPlaylist(let viewModels):
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FeaturedPlaylistCollectionViewCell.identifier, for:  indexPath) as? FeaturedPlaylistCollectionViewCell else {
                return UICollectionViewCell()
            }
            let viewModel = viewModels[indexPath.row]
            cell.configure(with: viewModel)
            return cell
        case .recommendedTracks(let viewModels):
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RecommendedTrackCollectionViewCell.identifier, for:  indexPath) as? RecommendedTrackCollectionViewCell else {
                return UICollectionViewCell()
            }
            let viewModel = viewModels[indexPath.row]
            cell.configure(with: viewModel)
            return cell
        }
 
    }
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TitleHeaderCollectionReusableView.identifier, for: indexPath) as? TitleHeaderCollectionReusableView, kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }
        let title = sections[indexPath.section].title
        header.configure(with: title)
        return header
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        // vibrate on select
        HapticManager.shared.vibrateForSelection()
        
        let section = sections[indexPath.section]
        switch section {
        case .featuredPlaylist:
            let playlist = playlists[indexPath.row]
            let vc = PlayListViewController(playlist: playlist)
            vc.navigationItem.largeTitleDisplayMode = .never
            vc.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(vc, animated: true)
        case .newReleases:
            let album = newAlbums[indexPath.row]
            let vc = AlbumViewController(album: album)
            vc.title = album.name
            vc.navigationItem.largeTitleDisplayMode = .never
            vc.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(vc, animated: true)
        case .recommendedTracks:
            let track = tracks[indexPath.row]
           // PlaybackPresenter.shared.startPlayback(from: self, track: track)
            AudioPlayerPresenter.shared.startPlayback(from: self, tracks: [track])
        }
    }
    
    static func createSectionLayout(section: Int) -> NSCollectionLayoutSection {
        
        let supplymentryViews = [
            NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(50)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        ]
        switch section {
        case 0:
            // Item
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(120)))
            item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
            // Vertical group in horisontal group
            let verticalGroup = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(390)),
                subitem: item,
                count: 3)
            
            let horizontalGroup = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.9), heightDimension: .absolute(390)),
                subitem: verticalGroup,
                count: 1 )
            // Section
            let section = NSCollectionLayoutSection(group: horizontalGroup)
            section.orthogonalScrollingBehavior = .groupPaging
            section.boundarySupplementaryItems = supplymentryViews
            return section
        case 1:
            // Item
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(160), heightDimension: .absolute(220)))
            item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
            
            // Vertical group in horisontal group
            let verticalGroup = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(160), heightDimension: .absolute(480)),
                subitem: item,
                count: 2)
            
            let horizontalGroup = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(160), heightDimension: .absolute(480)),
                subitem: verticalGroup,
                count: 1 )
            // Section
            let section = NSCollectionLayoutSection(group: horizontalGroup)
            section.orthogonalScrollingBehavior = .continuous
            section.boundarySupplementaryItems = supplymentryViews
            return section
        case 2:
            // Item
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
            item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
            // Vertical group in horisontal group
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(100)),
                subitem: item,
                count: 1)
            
            
            // Section
            let section = NSCollectionLayoutSection(group: group)
            section.boundarySupplementaryItems = supplymentryViews
            return section
        default:
            // Item
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(120)))
            item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
            // Vertical group in horisontal group
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(120)),
                subitem: item,
                count: 1)
            // Section
            let section = NSCollectionLayoutSection(group: group)
            section.boundarySupplementaryItems = supplymentryViews
            return section
        }
    }
}
