###
# Calculates the checksums for the otelcol-contrib files
# Usage: ruby tooling/checksums.rb <version>
##
# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'net/http'
require 'pp'

DOUBLES = [
  'darwin_amd64',
  'darwin_arm64',
  'linux_amd64',
  'linux_arm64'
]

version = ARGV[0]

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

def extract_collector(file, version, double)
  absolute_filepath = File.expand_path(file)
  new_filepath = File.join(File.dirname(absolute_filepath), "otelcol-contrib_#{version}_#{double}", File.basename(absolute_filepath))
  new_diretory = File.dirname(new_filepath)
  FileUtils.mkdir_p(new_diretory) unless File.directory?(new_diretory)

  file_path = File.expand_path(file)
  File.dirname(file_path)

  system("tar -xzf #{file}  -C ./otelcol-contrib_#{version}_#{double}")
end

DOUBLES.each do |double|
  host_os, architecture = double.split('_')

  url = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v#{version}/otelcol-contrib_#{version}_#{host_os}_#{architecture}.tar.gz"

  destination = "./otelcol-contrib_#{version}_#{host_os}_#{architecture}.tar.gz"

  download_collector(url, destination)

  extract_collector(destination, version, double)
end

checksums = DOUBLES.each_with_object({}) do |double, memo|
  host_os, architecture = double.split('_')
  file = "./otelcol-contrib_#{version}_#{double}/otelcol-contrib"

  checksum = Digest::SHA256.file(file).hexdigest
  memo[double] = checksum
end

pp checksums