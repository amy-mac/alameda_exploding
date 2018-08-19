require "sinatra"
require "date"
require "holidays"
require "httparty"
require 'iron_cache'
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
    holidays = Holidays.next_holidays(1, [:us, :hk])
  end

  # We only care about the holidays that might have explosions
  holidays.map { |holiday| holiday[:name] }.detect { |hol| FIREWORK_HOLIDAYS.include?(hol) }
end

def check_sports
  Scraper.new.check_for_games["teams"]
end

class Scraper
  attr_accessor :check_for_games

  SPORTS_TEAMS = %w[Athletics Giants Warriors].freeze
  VENUE_NAMES = ["AT&T Park", "Oakland Coliseum"].freeze

  def initialize
    @ironcache = IronCache::Client.new
    @sports_cache = @ironcache.cache("sports")
  end

  def simple_date
    @date ||= Date.today.strftime("%F")
  end

  def baseball_url(id)
    "https://statsapi.mlb.com/api/v1/teams/#{id}?hydrate=previousSchedule(date=#{simple_date},season=#{Date.today.year},limit=7,gameType=[E,S,R,A,F,D,L,W],team,linescore(matchup,runners),liveLookin,decisions,person,stats,game(content(summary)),seriesStatus(useOverride=true)),nextSchedule(date=#{simple_date},season=#{Date.today.year},limit=2,gameType=[E,S,R,A,F,D,L,W],team,linescore(matchup,runners),liveLookin,decisions,person,stats,game(content(summary)),seriesStatus(useOverride=true))&useLatestGames=true&language=en"
  end

  def basketball_url
    "https://www.nba.com/.element/media/2.0/teamsites/warriors/json/schedule-#{Date.today.year}.json"
  end

  def grab_page_info(team)
    case team
    when "Athletics"
      HTTParty.get(baseball_url("133")) # Team ID
    when "Giants"
      HTTParty.get(baseball_url("137")) # Team ID
    when "Warriors"
      HTTParty.get(basketball_url)
    end
  end

  def winning_baseball_game?(response)
    revised_response = response["teams"].first["nextGameSchedule"]["dates"].first

    home_game = revised_response["date"] == simple_date && VENUE_NAMES.include?(revised_response["games"][0]["venue"]["name"])

    return false unless home_game

    night_game = revised_response["games"].first["dayNight"] == "night"
    is_winner = revised_response["games"].first["teams"]["home"]["isWinner"]

    home_game && night_game && is_winner
  end

  def check_for_games
    return JSON.parse(@sports_cache.get("games").value) if @sports_cache.get("games")

    games = { teams: [] }

    SPORTS_TEAMS.each do |team|
      puts "Checking site for #{team}"

      response = grab_page_info(team)
      return unless response.code == 200

      if team == "Warriors"
        home_game = response["games"].detect do |game|
          game["home"] == true && game["date"] == simple_date
        end

        games[:teams] << team unless home_game.nil?
      else
        games[:teams] << team if winning_baseball_game?(response)
      end
    end

    # TODO: if winning game then take longer to expire
    @sports_cache.put("games", games.to_json, :expires_in => 120)
    JSON.parse(@sports_cache.get("games").value)
  end
end
