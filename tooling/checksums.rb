###
# Calculates the checksums for the otelcol-contrib files
# Usage: ruby tooling/checksums.rb <version>
##
# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'net/http'
require 'pp'
require 'pry'

DOUBLES = [
  'darwin_amd64',
  'darwin_arm64',
  'linux_amd64',
  'linux_arm64'
]

version = ARGV[0]

current_directory = Dir.pwd
unless current_directory.include?("/tooling")
  tooling_directory = File.join(current_directory, "/tooling")
  FileUtils.cd(tooling_directory)
end

def download_source_checksums(url, destination)
  uri = URI(url)

  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new(uri)
    http.request(request) do |response|
      return download_source_checksums(response['location'], destination) if response.code == '302'

      File.open(destination, 'wb') do |file|
        response.read_body do |chunk|
          file.write(chunk)
        end
      end
    end
  end
end

def validate_and_return_checksums(version)
  checksum_file_url = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v#{version}/opentelemetry-collector-releases_otelcol-contrib_checksums.txt"
  destination = "./opentelemetry-collector-releases_otelcol-contrib_checksums.txt"

  download_source_checksums(checksum_file_url, destination)

  contents = File.read(destination)
  lines = contents.split("\n")
  pairs = lines.each_with_object({}) do |item, hash|
    value, key = item.split
    hash[key] = value
  end


  relavent_pairs = {}
  DOUBLES.each do |double|
    file_name = "otelcol-contrib_#{version}_#{double}.tar.gz"
    file_location = "./#{file_name}"

    local_checksum = Digest::SHA256.file(file_location).hexdigest
    source_checksum = pairs[file_name]

    if source_checksum != local_checksum
      puts "#{double} contains different checksums: Local checksum #{local_checksum} -- Source checksum #{source_checksum}"
      raise "Different checksums for #{double}"
    end

    relavent_pairs[double] = local_checksum
  end

  relavent_pairs
end

def download_collector(url, destination)
  uri = URI(url)

  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new(uri)
    http.request(request) do |response|
      return download_collector(response['location'], destination) if response.code == '302'

      File.open(destination, 'wb') do |file|
        response.read_body do |chunk|
          file.write(chunk)
        end
      end
    end
  end
end

DOUBLES.each do |double|
  host_os, architecture = double.split('_')

  url = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v#{version}/otelcol-contrib_#{version}_#{host_os}_#{architecture}.tar.gz"

  destination = "./otelcol-contrib_#{version}_#{host_os}_#{architecture}.tar.gz"

  download_collector(url, destination)
end

checksums = validate_and_return_checksums(version)

pp checksums