# # encoding: UTF-8

require 'google_calendar'
require 'dotenv'
Dotenv.load

class GoogleCustomEvent
  def initialize(event)
    @event = event
  end
  attr_reader :event

  def to_json(*args)
    {
      title: event.title,
      start: event.start_time,
      end: event.end_time
    }.to_json
  end
end

SCHEDULER.every '1h', :first_in => 0 do |job|
  cal = Google::Calendar.new(
    client_id: ENV['GOOGLE_CLIENT_ID'],
    client_secret: ENV['GOOGLE_CLIENT_SECRET'],
    calendar: 'mpalhas@gmail.com',
    redirect_url: 'http://localhost/callback/'
  )

  if ENV['GOOGLE_REFRESH_TOKEN']
    cal.login_with_refresh_token(ENV['GOOGLE_REFRESH_TOKEN'])
  else
    puts 'Do you already have a refresh token? (y/n)'
    has_token = $stdin.gets.chomp

    if has_token.downcase != 'y'
      puts 'Visit the following web page in your browser and approve access.'
      puts cal.authorize_url
      puts '\nCopy the code that Google returned and paste it here:'

      refresh_token = cal.login_with_auth_code($stdin.gets.chomp)

      puts '\nMake sure you SAVE YOUR REFRESH TOKEN so you don\'t have to prompt the user to approve access again.'
      puts "your refresh token is:\n\t#{refresh_token}\n"
      puts 'Press return to continue'
      $stdin.gets.chomp
    else
      puts 'Enter your refresh token'
      refresh_token = $stdin.gets.chomp
      cal.login_with_refresh_token(refresh_token)
    end
  end

  events = cal.events.map do |event|
    GoogleCustomEvent.new(event)
  end

  send_event('google_calendar', { events: events })
end
