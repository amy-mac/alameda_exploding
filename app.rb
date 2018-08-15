require "sinatra"
require "sinatra/reloader" if development?
require "Date"
require "Holidays"
require "HTTParty"
require "Nokogiri"
require "pry" if development?

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
  Scraper.new.check_for_games
end

class Scraper
  attr_accessor :check_for_games

  SPORTS_TEAMS = %w[Athletics Giants Warriors].freeze

  def grab_page_info(team)
    case team
    when "Athletics"
      HTTParty.get("https://statsapi.mlb.com/api/v1/schedule?sportId=1&gamePk=531221&hydrate=team,linescore,flags,liveLookin,review,person,stats,probablePitcher,game(content(summary,media(epg)),tickets)&useLatestGames=true&language=en")
    when "Giants"
      HTTParty.get("https://statsapi.mlb.com/api/v1/schedule?sportId=1&gamePk=531220&hydrate=team,linescore,flags,liveLookin,review,person,stats,probablePitcher,game(content(summary,media(epg)),tickets)&useLatestGames=true&language=en")
    when "Warriors"
      HTTParty.get("https://www.nba.com/.element/media/2.0/teamsites/warriors/json/schedule-2018.json")
    end
  end

  def check_for_games
    games = []

    SPORTS_TEAMS.each do |team|
      response = grab_page_info(team)

      if team == "Warriors"
        home_game = response["games"].detect do |game|
          game["home"] == true && game["date"] == Date.today.strftime("%F")
        end

        games << team unless home_game.nil?
      elsif team == "Athletics"
        home_game = response["dates"].first["date"] == Date.today.strftime("%F") && response["dates"].first["games"].first["venue"]["name"] == "Oakland Coliseum"

        if home_game
          night_game = response["dates"].first["games"].first["dayNight"] == "night"
          is_winner = response["dates"].first["games"].first["teams"]["home"]["isWinner"]
        end

        games << team if home_game && night_game && is_winner
      elsif team == "Giants"
        home_game = response["dates"].first["date"] == Date.today.strftime("%F") && response["dates"].first["games"].first["venue"]["name"] == "AT&T Park"

        if home_game
          night_game = response["dates"].first["games"].first["dayNight"] == "night"
          is_winner = response["dates"].first["games"].first["teams"]["home"]["isWinner"]
        end

        games << team if home_game && night_game && is_winner
      end
    end

    games
  end
end
