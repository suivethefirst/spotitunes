require 'sinatra'
require 'httparty'
require 'json'

def parseMessage(message)
	spotifyURL = /spotify:(\balbum|\btrack):[a-zA-Z0-9]+/.match(message)
	return spotifyURL.to_s
end

def getArtistAlbumFromSpotifyURL(spotifyURL)
	spotifyParsed = spotifyURL.split(':')
	url = "https://api.spotify.com/v1/albums/#{spotifyParsed[2]}"
	json_response = JSON.parse(HTTParty.get(url).body)
	return json_response['artists'][0]['name'] + ' ' + json_response['name']
end

def getiTunesFirstCollectionView(searchTerm)
	url = "https://itunes.apple.com/search?term=#{searchTerm}&country=GB"
	json_response = JSON.parse(HTTParty.get(url))
	return json_response['results'].first['collectionViewUrl']
end

# puts getFirstCollectionView('sepultura')
# puts getiTunesFirstCollectionView(getArtistAlbumFromSpotifyURL(parseMessage(ARGV[0])))

