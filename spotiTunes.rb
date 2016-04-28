require 'sinatra'
require 'httparty'
require 'json'
require 'oga'
require 'uri'
require 'json'


	$linkTypes = {
		'notfound' => 0,
		'spotify' => 1,
		'itunes' => 2,
		'gmusic' => 3,
		'gmusicshare' => 4
	}

def parseMessage(message)

	gmusicURL = /https:\/\/play\.google\.com\/music\/listen\?u\=0\#\/album\/.*\/.*\/[^>]*/.match(message)

	if !(gmusicURL.nil?)
		gmusicURL = gmusicURL.to_s.split('/')
		gmusicUUID = URI.unescape(gmusicURL[6].to_s)
		gmusicANSIArtist = URI.unescape(gmusicURL[7].to_s.tr("+", " "))
		gmusicANSIAlbum = URI.unescape(gmusicURL[8].to_s.tr("+", " "))

		gmusicHash = {
			'type' => gmusicANSIArtist,
			'id' => gmusicANSIAlbum
		}
		
		resultHash = {
			'type' => $linkTypes['gmusic'],
			'content' => gmusicHash,
			'gmusicuuid' => gmusicUUID
		}

		return resultHash
	end

	gmusicURL = /https:\/\/play\.google\.com\/music\/m\/.*\?t\=.*_-_[^>]*/.match(message)

	if !(gmusicURL.nil?)
		gmusicAlbumDelimiter = '\?t\='
		gmusicAristDelimiter = '_-_'
		gmusicAlbum = gmusicURL.to_s[/#{gmusicAlbumDelimiter}(.*?)#{gmusicAristDelimiter}/m, 1]
		gmusicArtist = gmusicURL.to_s.split('_-_')
		gmusicANSIArtist = URI.unescape(gmusicArtist[1].to_s.tr("_", " "))
		gmusicANSIAlbum = URI.unescape(gmusicAlbum.to_s.tr("_", " "))
		print 
		gmusicHash = {
			'type' => gmusicANSIArtist,
			'id' => gmusicANSIAlbum
		}
		
		resultHash = {
			'type' => $linkTypes['gmusicshare'],
			'content' => gmusicHash
		}

		return resultHash
	end

	spotifyURL = /spotify:(\balbum|\btrack):[a-zA-Z0-9]+/.match(message)

	if !(spotifyURL.nil?)
		spotifyURL = spotifyURL.to_s.split(':')
		spotifyHash = {
			'type' => spotifyURL[1],
			'id' => spotifyURL[2]
		}

		resultHash = {
			'type' => $linkTypes['spotify'],
			'content' => spotifyHash
		}

		return resultHash
	end

	spotifyURL = /https:\/\/play\.spotify\.com\/(\btrack|\balbum)\/([a-zA-Z0-9])+/.match(message)

	if !(spotifyURL.nil?)
		spotifyURL = spotifyURL.to_s.split('/')
		spotifyHash = {
			'type' => spotifyURL[3],
			'id' => spotifyURL[4]
		}

		resultHash = {
			'type' => $linkTypes['spotify'],
			'content' => spotifyHash
		}

		return resultHash
	end

	iTunesURL = /https:\/\/itun\.es\/([a-zA-Z0-9\/\-\_])+/.match(message)

	if !(iTunesURL.nil?)
		response = HTTParty.head(iTunesURL.to_s, follow_redirects: false)
		url = response.headers['location']

		iTunesID = url.to_s.split('/')[6][2..-1]

		resultHash = {
			'type' => $linkTypes['itunes'],
			'content' => iTunesID
		}

		return resultHash
	end

	iTunesURL = /https:\/\/itunes\.apple\.com\/([a-zA-Z0-9\/\-\_])+/.match(message)

	if !(iTunesURL.nil?)
		iTunesID = iTunesURL.to_s.split('/')[6][2..-1]

		resultHash = {
			'type' => $linkTypes['itunes'],
			'content' => iTunesID
		}

		return resultHash
	end
	
	resultHash = {
		'type' => $linkTypes['notfound'],
		'content' => ''
	}

end

def getArtistAlbumFromSpotifyURL(spotifyHash)

	url = "https://api.spotify.com/v1/#{spotifyHash['type']}s/#{spotifyHash['id']}"

	json_response = JSON.parse(HTTParty.get(url).body)
	return json_response['artists'][0]['name'] + ' ' + json_response['name']

end

def getArtistAlbumFromiTunesID(iTunesID)

	url = "https://itunes.apple.com/lookup?id=#{iTunesID}&country=gb"

	json_response = JSON.parse(HTTParty.get(url).body)
	return json_response['results'][0]['artistName'] + ' ' + json_response['results'][0]['collectionName']

end

def getArtistAlbumFromGoogleURL(gmusicHash)

	return "#{gmusicHash['type']} #{gmusicHash['id']}"

end

def getSpotifyFirstHit(searchTerm)

	url ="https://api.spotify.com/v1/search?q=#{searchTerm}&type=album,track"

	begin
		json_response = JSON.parse(HTTParty.get(url).body)
		spotifyLink = json_response['albums']['items'][0]['external_urls']['spotify']
	rescue Exception => e
		return "Couldn't get this one from Spotify"
	end

	return spotifyLink

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

def buildGMusicShareURL(artistAlbum,gmusicUUID)

	url = "https://play.google.com/music/m/#{gmusicUUID}?t=#{artistAlbum['id']}_-_#{artistAlbum['type']}"

	return url
end

post '/spotitunes' do

	if params[:token] != ENV['SLACK_TOKEN']
		return
	end

	if params[:user_name] == 'slackbot'
		return
	end

	posting_user = params[:user_name]
	searchHash = parseMessage(params[:text])

	case searchHash['type']

	when $linkTypes['notfound']

		return

	when $linkTypes['spotify']

		artistAlbum = getArtistAlbumFromSpotifyURL(searchHash['content'])

		itunesLink = getiTunesFirstCollectionView(artistAlbum)
		gPlayLink = getGPlayFirstAlbum(artistAlbum)

		outputmessage = ":applemusic: " + itunesLink + "\n\n" + ":googleplay: " + gPlayLink

	when $linkTypes['itunes']

		artistAlbum = getArtistAlbumFromiTunesID(searchHash['content'])

		spotifyLink = getSpotifyFirstHit(artistAlbum)
		gPlayLink = getGPlayFirstAlbum(artistAlbum)

		outputmessage = ":spotify: " + spotifyLink + "\n\n" + ":googleplay: " + gPlayLink

	when $linkTypes['gmusic']

		artistAlbum = getArtistAlbumFromGoogleURL(searchHash['content'])
		gPlayLink = buildGMusicShareURL(searchHash['content'],searchHash['gmusicuuid'])

		HTTParty.post(ENV['SLACK_WEBHOOK'].to_str, :body => { :text => "<#{gPlayLink}>" }.to_json, :headers => { 'Content-Type' => 'application/json' } )

		spotifyLink = getSpotifyFirstHit(artistAlbum)
		itunesLink = getiTunesFirstCollectionView(artistAlbum)

		outputmessage = ":spotify: " + spotifyLink + "\n\n" + ":applemusic: " + itunesLink

	when $linkTypes['gmusicshare']

		artistAlbum = getArtistAlbumFromGoogleURL(searchHash['content'])

		spotifyLink = getSpotifyFirstHit(artistAlbum)
		itunesLink = getiTunesFirstCollectionView(artistAlbum)

		outputmessage = ":spotify: " + spotifyLink + "\n\n" + ":applemusic: " + itunesLink

	end

	content_type :json
	{:text => outputmessage,
	 :unfurl_links => false,
	 :unfurl_media => false}.to_json

end
