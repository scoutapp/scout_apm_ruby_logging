# frozen_string_literal: true

require 'spec_helper'

require 'rails'

describe ScoutApm::Logging do
  before(:all) do
    # Run the Railtie initializers to trigger the daemon spawning
    make_basic_app
  end

  it "spawns the daemon process" do
    # Check if the PID file exists
    expect(File.exist?(ScoutApm::Logging::MonitorManager::PID_FILE)).to be_truthy

    # Read the PID from the PID file
    pid = File.read(ScoutApm::Logging::MonitorManager::PID_FILE).to_i

    # Check if the process with the stored PID is running
    expect(Process.kill(0, pid)).to be_truthy
  end

  after(:all) do
    process = File.read(ScoutApm::Logging::MonitorManager::PID_FILE).to_i
    Process.kill('TERM', process)
    File.delete(ScoutApm::Logging::MonitorManager::PID_FILE)
  end
end
