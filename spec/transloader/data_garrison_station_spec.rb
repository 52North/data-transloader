require 'transloader'

require 'fileutils'
require 'rspec'
require 'time'
require 'vcr'

RSpec.describe Transloader::DataGarrisonStation do

  ##############
  # Get Metadata
  ##############
  
  context "Downloading Metadata" do
    before(:each) do
      reset_cache($cache_dir)

      # Use instance variables to avoid scope issues with VCR
      @provider = nil
      @station = nil
    end

    it "downloads the station metadata when saving the metadata" do
      VCR.use_cassette("data_garrison/station") do
        metadata_file = "#{$cache_dir}/data_garrison/metadata/300234063581640/300234065673960.json"
        expect(File.exist?(metadata_file)).to be false

        @provider = Transloader::DataGarrisonProvider.new($cache_dir)
        @station = @provider.get_station(
          user_id: "300234063581640",
          station_id: "300234065673960"
        )
        @station.save_metadata

        expect(WebMock).to have_requested(:get, 
          %r[https://datagarrison\.com/users/300234063581640/300234065673960/index\.php.+]).times(1)
        expect(File.exist?(metadata_file)).to be true
      end
    end

    it "raises an error if metadata source file cannot be downloaded" do
      VCR.use_cassette("data_garrison/station_not_found") do
        @provider = Transloader::DataGarrisonProvider.new($cache_dir)
        expect {
          @provider.get_station(
            user_id: "300234063581640",
            station_id: "300234065673960"
          )
        }.to raise_error(OpenURI::HTTPError)
      end
    end

    it "overwrites metadata file if it already exists" do
      VCR.use_cassette("data_garrison/station") do
        metadata_file = "#{$cache_dir}/data_garrison/metadata/300234063581640/300234065673960.json"

        @provider = Transloader::DataGarrisonProvider.new($cache_dir)
        @station = @provider.get_station(
          user_id: "300234063581640",
          station_id: "300234065673960"
        )
        @station.save_metadata
        # drop the modified time back 1 day, so we can check to see if
        # it is actually updated
        File.utime((Time.now - 86400), (Time.now - 86400), metadata_file)
        mtime = File.stat(metadata_file).mtime

        @station.save_metadata

        expect(File.stat(metadata_file).mtime).to_not eq(mtime)
      end
    end
  end

  ##############
  # Put Metadata
  ##############
  
  context "Uploading Metadata" do
    # pre-create the station for this context block
    before(:each) do
      reset_cache($cache_dir)
      @provider = nil
      @station = nil

      VCR.use_cassette("data_garrison/station") do
        @provider = Transloader::DataGarrisonProvider.new($cache_dir)
        @station = @provider.get_station(
          user_id: "300234063581640",
          station_id: "300234065673960"
        )
        # These values must be fixed before uploading to STA.
        @station.metadata[:latitude] = 69.158
        @station.metadata[:longitude] = -107.0403
        @station.metadata[:timezone_offset] = "-06:00"
        # Fix for error in source data
        @station.metadata[:datastreams].last[:id] = "Battery Voltage"
        @station.save_metadata
      end

      @sensorthings_url = "http://192.168.33.77:8080/FROST-Server/v1.0/"
    end

    it "creates a Thing entity and caches the entity URL" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          "#{@sensorthings_url}Things").once
        expect(@station.metadata[:"Thing@iot.navigationLink"]).to_not be_empty
      end
    end

    it "creates a Location entity and caches the entity URL" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Locations]).once
        expect(@station.metadata[:"Location@iot.navigationLink"]).to_not be_empty
      end
    end

    it "creates Sensor entities and caches the URLs" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Sensors]).at_least_once
        expect(@station.metadata[:datastreams][0][:"Sensor@iot.navigationLink"]).to_not be_empty
      end
    end

    it "creates Observed Property entities and caches the URLs" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}ObservedProperties]).at_least_once
        expect(@station.metadata[:datastreams][0][:"ObservedProperty@iot.navigationLink"]).to_not be_empty
      end
    end

    it "maps the source observed properties to standard observed properties" do
      pending
      fail
    end

    it "creates Datastream entities and caches the URLs" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams]).at_least_once
        expect(@station.metadata[:datastreams][0][:"Datastream@iot.navigationLink"]).to_not be_empty
      end
    end

    it "maps the source observation type to O&M observation types on Datastreams" do
      pending
      fail
    end

    it "maps the source observation type to standard UOMs on Datastreams" do
      pending
      fail
    end
  end
end
