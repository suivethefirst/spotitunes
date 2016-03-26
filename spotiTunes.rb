require 'sinatra'
require 'httparty'
require 'json'
require 'oga'

linkTypes = {
	'notfound' => 0,
	'spotify' => 1,
	'itunes' => 2
}

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

	iTunesURL = /https:\/\/itunes.apple.com\/.+/.match(message)

	if !(iTunesURL.nil?)
		iTunesID = iTunesURL.split('/')[6][2..-1]
		return iTunesID
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

def getArtistAlbumFromiTunesID(iTunesID)

	url = "https://itunes.apple.com/lookup?id=#{iTunesID}"

	json_response = JSON.parse(HTTParty.get(url).body)
	return json_response['results'][0]['artistName'] + ' ' + json_response['results'][0]['collectionName']

end

def getSpotifyFirstHit(searchTerm)

	url ="https://api.spotify.com/v1/search?q=#{searchTerm}&type=album,track"

	json_response = JSON.parse(HTTParty.get(url).body)

	return json_response['albums']['items'][0]['external_urls']['spotify']

end

def getiTunesFirstCollectionView(searchTerm)

	url = "https://itunes.apple.com/search?term=#{searchTerm}&country=GB"

	begin
		json_response = JSON.parse(HTTParty.get(url))
		itunesLink = json_response['results'].first['collectionViewUrl']
	rescue Exception => e
		return "Couldn't get this one from iTunes :("
	end

	return itunesLink 

end

def getGPlayFirstAlbum(searchTerm)

	url = "https://play.google.com/store/search?q=#{searchTerm}&c=music&docType=2"
	
	begin
		response = HTTParty.get(url, verify: false).body
		document = Oga.parse_html(response)
		results = document.xpath("//a[@class='card-click-target']")

		id = results[0].get('href').split('id=')[1]

		gPlayLink = "https://play.google.com/music/listen?view=#{id}_cid&authuser=0"
	rescue Exception => e
		return "Couldn't get this one from Google Play"
	end
	
	return gPlayLink
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

		outputmessage = itunesLink + "\n" + gPlayLink

		content_type :json
		{:text => outputmessage}.to_json
	end

end
