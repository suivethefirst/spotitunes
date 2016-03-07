require 'sinatra'
require 'httparty'
require 'json'
require 'oga'

def parseMessage(message)

	spotifyURL = /spotify:(\balbum|\btrack):[a-zA-Z0-9]+/.match(message)

	if !(spotifyURL.nil?)
		spotifyURL = spotifyURL.to_s.split(':')
		spotifyHash = {
			'type' => spotifyURL[1],
			'id' => spotifyURL[2]
		}
		return spotifyHash
	end

	spotifyURL = /https:\/\/play.spotify.com\/(\btrack|\balbum)\/([a-zA-Z0-9])+/.match(message)

	if !(spotifyURL.nil?)
		spotifyURL = spotifyURL.to_s.split('/')
		spotifyHash = {
			'type' => spotifyURL[3],
			'id' => spotifyURL[4]
		}
		return spotifyHash
	end

	if spotifyURL.nil?
		return "-1"
	end

end

def getArtistAlbumFromSpotifyURL(spotifyHash)

	url = "https://api.spotify.com/v1/#{spotifyHash['type']}s/#{spotifyHash['id']}"

	json_response = JSON.parse(HTTParty.get(url).body)
	return json_response['artists'][0]['name'] + ' ' + json_response['name']

end

def getiTunesFirstCollectionView(searchTerm)

	url = "https://itunes.apple.com/search?term=#{searchTerm}&country=GB"
	json_response = JSON.parse(HTTParty.get(url))

	return json_response['results'].first['collectionViewUrl']

end

def getGPlayFirstAlbum(searchTerm)
	baseURL = "https://play.google.com"
	url = "https://play.google.com/store/search?q=#{searchTerm}&c=music&docType=2"
	
	response = HTTParty.get(url, verify: false).body
	document = Oga.parse_html(response)
	results = document.xpath("//a[@class='card-click-target']")
	return baseURL + results[0].get('href')
end



post '/spotitunes' do

	if params[:token] != ENV['SLACK_TOKEN']
		return
	end

	message = params[:text]

	if (spotifyURL = parseMessage(message)) != "-1"

		artistAlbum = getArtistAlbumFromSpotifyURL(spotifyURL)
		itunesLink = getiTunesFirstCollectionView(artistAlbum)
		gPlayLink = getGPlayFirstAlbum(artistAlbum)

		outputmessage = itunesLink + ' \n\n ' + gPlayLink

		content_type :json
		{:text => outputmessage}.to_json
	end

end
