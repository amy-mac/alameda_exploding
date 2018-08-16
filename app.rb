require "sinatra"
require "date"
require "holidays"
require "HTTParty"
require "pry" if development?
require "sinatra/reloader" if development?


# ROUTES/ACTIONS

get "/" do
  @holidays = check_holidays
  @sports = check_sports

  erb :index
end


# CLASSES/METHODS

FIREWORK_HOLIDAYS = [
  "Independence Day",
  "New Year's Eve",
  "Lunar New Year's Day",
  "The second day of Lunar New Year",
  "The third day of Lunar New Year"
].freeze

def check_holidays
  logger.info "Checking Holidays"
  today = Date.today
  holidays = Holidays.on(today, :us, :hk)

  # Might be the week of Independence Day, etc
  if holidays.empty? && Holidays.any_holidays_during_work_week?(today)
    holidays = Holidays.next_holidays(1, [:us, :uk])
  end

  # We only care about the holidays that might have explosions
  holidays.map { |holiday| holiday[:name] }.detect { |hol| FIREWORK_HOLIDAYS.include?(hol) }
end

def check_sports
  @check_sports ||= Scraper.new.check_for_games
end

class Scraper
  attr_accessor :check_for_games

  SPORTS_TEAMS = %w[Athletics Giants Warriors].freeze
  VENUE_NAMES = ["AT&T Park", "Oakland Coliseum"].freeze

  def simple_date
    @date ||= Date.today.strftime("%F")
  end

  def baseball_url(id)
    "https://statsapi.mlb.com/api/v1/schedule?sportId=1&gamePk=#{id}&hydrate=team,linescore,flags,liveLookin,review,person,stats,probablePitcher,game(content(summary,media(epg)),tickets)&useLatestGames=true&language=en"
  end

  def basketball_url
    "https://www.nba.com/.element/media/2.0/teamsites/warriors/json/schedule-#{Date.today.year}.json"
  end

  def grab_page_info(team)
    case team
    when "Athletics"
      HTTParty.get(baseball_url("531221"))
    when "Giants"
      HTTParty.get(baseball_url("531220"))
    when "Warriors"
      HTTParty.get(basketball_url)
    end
  end

  def winning_baseball_game?(response)
    response = response["dates"].first

    home_game = response["date"] == simple_date && VENUE_NAMES.include?(response["games"][0]["venue"]["name"])

    return false unless home_game

    night_game = response["games"].first["dayNight"] == "night"
    is_winner = response["games"].first["teams"]["home"]["isWinner"]

    home_game && night_game && is_winner
  end

  def check_for_games
    games ||= []

    SPORTS_TEAMS.each do |team|
      puts "Checking site for #{team}"

      response = grab_page_info(team)
      return unless response.code == 200

      if team == "Warriors"
        home_game = response["games"].detect do |game|
          game["home"] == true && game["date"] == simple_date
        end

        games << team unless home_game.nil?
      else
        games << team if winning_baseball_game?(response)
      end
    end

    games
  end
end
