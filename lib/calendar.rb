# insert event into calendar, at given time, in given room
# default to one hour
# use organizer name

require 'date'
require 'json'
require 'jwt'
require 'net/http'
require 'digest/sha2'
require 'openssl'

class Authentication
    JARVIS_SECRET_PATH = "../Jarvis-8746cc8b4449.json"
    JARVIS_GOOGLE_SCOPE = "https://www.googleapis.com/auth/calendar"
    GOOGLE_AUD_URL = "https://accounts.google.com/o/oauth2/token"
    GOOGLE_GRANT_TYPE = "urn:ietf:params:oauth:grant-type:jwt-bearer"
    
    attr_accessor :token, :response_dict

    def initialize
        uri = URI(GOOGLE_AUD_URL)
        grant_type = GOOGLE_GRANT_TYPE
        response_body = Net::HTTP.post_form(uri, {"grant_type" => grant_type,
                                                      "assertion" => make_jwt}).body
        @response_dict = JSON.parse(response_body)
        @token = @response_dict["access_token"]
    end
    
    def make_jwt
        secret_json = File.read(File.join(File.expand_path(File.dirname(__FILE__)), JARVIS_SECRET_PATH))
        secret_dictionary = JSON.parse(secret_json)
        iss = secret_dictionary['client_email']
        iat = DateTime.now.to_time.strftime('%s').to_i
        exp = iat + 60 * 60 # expires 1 hour (60*60) from now
        jwt_claim = {
           "iss" => iss,
           "scope" => JARVIS_GOOGLE_SCOPE,
           "aud" => GOOGLE_AUD_URL,
           "exp" => exp,
           "iat" => iat
        }

        ssl_key = OpenSSL::PKey::RSA.new secret_dictionary['private_key']
        JWT.encode(jwt_claim, ssl_key, "RS256")
    end
end

class Calendar
    JARVIS_TEST_CALENDAR_ID = "27oim6lpetk763ipds6au4cmgc@group.calendar.google.com"
    API_BASE = "https://www.googleapis.com/calendar/v3/calendars/#{JARVIS_TEST_CALENDAR_ID}"
        # todo: factor out id
    JARVIS_SECRET_FILE_2 = "../Jarvis-a71ef323eab2.p12" 
    attr_accessor :id
    
    def initialize(id = JARVIS_TEST_CALENDAR_ID) 
        @auth_token = Authentication.new.token
        @id = id
    end
    
    def events
        #use http to make get request to google
        events_url = API_BASE + "/events?access_token=#{@auth_token}"
        response = Net::HTTP.get(URI(events_url))
        JSON.parse(response)['items']
        # wrap in class pulling out all google stuff
            # look at items, make sure it's there!
            # ANOTHER class handles the internals of items
    end
    
        
    def quick_add(text)
        res = post_api_request("/events/quickAdd", {'text' => text}, nil)
        JSON.parse(res.body)
    end
    
# Add a calendar event
# 
# start_time - Ruby DateTime object, must be before end_time and have its time
#              zone offset correctly set (e.g. start_time.new_offset("-04:00"))
# end_time - Ruby DateTime object, must be after start_time and have its time
#            zone offset correctly set (e.g. start_time.new_offset("-04:00"))
# room - string, will be set as event location
# description - string, will be set as event summary (or 'title' to us normal people)
#
# Returns ????
    def add(start_time, end_time, room, description)
        params = {
            "end" => {
                "dateTime" => end_time.rfc3339
            },
            "start" => {
                "dateTime" => start_time.rfc3339
            },
            "location" => room,
            "summary" => description
        }.to_json
    
        res = post_api_request("/events", nil, params)
        JSON.parse(res.body)
    end
    
    private
        def post_api_request(relative_url, form_data, request_body)
            uri = URI(API_BASE + relative_url)
            req = Net::HTTP::Post.new(uri)
            req.set_form_data(form_data) if form_data
            if request_body
                req.body = request_body
                req['Content-Type'] = 'application/json'
            end
            req['Authorization'] = "Bearer #{@auth_token}"
            res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
                http.request(req)
            end
            res
        end
    
#     d = DateTime.new(2014,8,9,10,35)
#     d.new_offset("-04:00").rfc3339
end
