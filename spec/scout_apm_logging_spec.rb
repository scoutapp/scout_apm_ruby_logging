# frozen_string_literal: true

require 'spec_helper'

describe ScoutApm::Logging do
  let(:hello_world) do
    Class.new(ScoutApm::Logging::Hello)
  end

  it 'writes hello world' do
    allow($stdout).to receive(:puts)
    expect { hello_world.world }.to output("Hello World.\n").to_stdout
  end
end
