require "spec_helper"

describe "Is Alameda Exploding App" do
  def app
    Sinatra::Application
  end

  it "renders the page successfully" do
    get "/"
    expect(last_response).to be_ok
    expect(last_response.body).to include("What are those loud noises in Alameda?")
  end

  describe "#check_holidays" do
    subject { app.send(:check_holidays) }

    context "when there are no holidays today" do
      context "and there are no holidays this week" do
        before do
          allow(Date).to receive(:today).and_return(Date.civil(2018, 03, 10))
        end

        it "returns nil" do
          is_expected.to be_nil
        end
      end

      context "and there are firework holidays this week" do
        before do
          allow(Date).to receive(:today).and_return(Date.civil(2018, 07, 03))
        end

        it "returns the firework holiday taking place this week" do
          is_expected.to eq("Independence Day")
        end
      end
    end

    context "when there are holidays today" do
      context "and none of them are firework holidays" do
        before do
          allow(Date).to receive(:today).and_return(Date.civil(2018, 12, 25))
        end

        it "returns nil" do
          is_expected.to be_nil
        end
      end

      context "and they are firework holidays" do
        before do
          allow(Date).to receive(:today).and_return(Date.civil(2018, 12, 31))
        end

        it "returns the holidays" do
          is_expected.to eq("New Year's Eve")
        end
      end
    end
  end
end
