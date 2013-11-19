require 'sinatra'
require 'twilio-ruby'

include Twilio::REST

post '/message' do
  content_type 'text/xml'
	"<Response>
    <Message>Thanks for coming to see Twilio! Get started for free at http://www.twilio.com</Message>
	</Response>"
end

post '/call' do
  content_type 'text/xml'
	"<Response>
	  <Play>#{ENV['MUSIC_URI']}</Play>
	</Response>"
end

post '/trigger' do
	content_type 'text/xml'
  if secured?(params,request)
    if params[:Body].downcase == 'forward'
			forward
    elsif params[:Body].downcase == 'dial'
		  dial "http://#{request.host}/call"
		else
      "<Response><Message>To use the automated trigger: Text 'forward' to forward all messages from this demo to yourself. Text 'dial' to dial all calls back and play some music.</Message></Response>"
		end
	end	
end

# If using Heroku or similar, accessing this can make sure the service is awake. If no data connection, text a random work to trigger number and get the instructions back instead.
get '/wakeup' do
  "OK"
end

# Gets the list of messages, which we need for both operations.
def get_messages
  @client = Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
	client.account.messages.list(to: ENV['PUBLIC_SMS_NUMBER'], 'date_sent>' => (Time.new - 600).to_s[0..-7])
end

# Creates an outbound dial to the url...
def dial url
	get_messages.each {|msg| @client.account.calls.create(to: msg.from, from: ENV[PUBLIC_CALL_NUMBER], url: url)}
end

#get all the messages to the public number in the last 10 minutes, and forward them to yourself.
def forward
	get_messages.each {|msg| @client.account.messages.create(to: params[:From], from: ENV['PRIVATE_SMS_NUMBER'], body: msg.body) }
	#If your account is rate limited, this will probably time out and cause an error.
	"<Response/>"
end

def secured? params, request
  true

end

def garbage params, request
	validator = Twilio::Util::RequestValidator.new ENV['TWILIO_AUTH_TOKEN']
	# the callback URL you provided to Twilio
	url = request.url
	# notice the From value is from the environment variable, so the request must be from that caller ID or it is invalid irrespective. 
  # Therefore, knowing the command number doesn't allow anyone to take control of the demo.
	post_vars = {:From => ENV['USER_CALLER_ID'], :To => params[:To], :Body => params[:Body], :NumMedia => params[:NumMedia], :MessageSid => params[:MessageSid], :AccountSid => params[:AccountSid], :SmsSid => params[:SmsSid]}
	signature = request['X-Twilio-Signature']
	# Make sure the request is from both Twilio and the allowed Caller ID...
  validator.validate(url, post_vars, signature)
end
