require 'sinatra'
require 'httparty'
require 'json'

def parseMessage(message)

	spotifyURL = /spotify:(\balbum|\btrack):[a-zA-Z0-9]+/.match(message)

	if spotifyURL.nil?
		return "-1"
	else
		return spotifyURL.to_s
	end

end

def getArtistAlbumFromSpotifyURL(spotifyURL)

	spotifyParsed = spotifyURL.split(':')

	if spotifyParsed[1] = 'album'
		url = "https://api.spotify.com/v1/albums/#{spotifyParsed[2]}"
	elsif spotifyParsed[1] = 'track'
		url = "https://api.spotify.com/v1/tracks/#{spotifyParsed[2]}"
	end

	json_response = JSON.parse(HTTParty.get(url).body)
	return json_response['artists'][0]['name'] + ' ' + json_response['name']

end

def getiTunesFirstCollectionView(searchTerm)

	url = "https://itunes.apple.com/search?term=#{searchTerm}&country=GB"
	json_response = JSON.parse(HTTParty.get(url))

	return json_response['results'].first['collectionViewUrl']

end

get '/' do
	'Hello'
end

post '/spotitunes' do

	if params[:token] != ENV['SLACK_TOKEN']
		return
	end

	message = params[:text]

	if (spotifyURL = parseMessage(message)) != "-1"

		artistAlbum = getArtistAlbumFromSpotifyURL(spotifyURL)
		itunesLink = getiTunesFirstCollectionView(artistAlbum)

		content_type :json
		{:text => itunesLink}.to_json
	end

end
