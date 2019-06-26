require 'transloader'

require 'rspec'
require 'vcr'

RSpec.describe Transloader::EnvironmentCanadaProvider do
  before(:each) do
    reset_cache($cache_dir)
  end

  it "auto-creates a cache directory" do
    Transloader::EnvironmentCanadaProvider.new($cache_dir)
    expect(Dir.exist?("#{$cache_dir}/environment_canada/metadata")).to be true
  end

  it "creates a station object with the given id" do
    VCR.use_cassette("environment_canada_stations") do
      provider = Transloader::EnvironmentCanadaProvider.new($cache_dir)
      station = provider.get_station(station_id: "CXCM")

      expect(station.id).to eq("CXCM")
      expect(station.metadata).to_not eq({})
    end
  end

  it "initializes a new station without loading any metadata" do
    VCR.use_cassette("environment_canada_stations") do
      provider = Transloader::EnvironmentCanadaProvider.new($cache_dir)
      station = provider.new_station(station_id: "CXCM")
      expect(station.metadata).to eq({})
    end
  end

  it "returns an array of available stations" do
    VCR.use_cassette("environment_canada_stations") do
      provider = Transloader::EnvironmentCanadaProvider.new($cache_dir)

      expect(provider.stations).to_not be_empty
    end
  end

  it "raises an error when stations cannot be downloaded" do
    VCR.use_cassette("environment_canada_stations_not_found") do
      provider = Transloader::EnvironmentCanadaProvider.new($cache_dir)
      expect {
        provider.stations
      }.to raise_error("Error downloading station list")
    end
  end

  it "does not make an HTTP request if data is already cached" do
    VCR.use_cassette("environment_canada_stations") do
      provider = Transloader::EnvironmentCanadaProvider.new($cache_dir)
      provider.stations
      provider.stations
      expect(WebMock).to have_requested(:get, Transloader::EnvironmentCanadaProvider::METADATA_URL).times(1)
    end
  end
end
