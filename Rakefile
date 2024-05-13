task :default => :test

task :test do
  unless system("docker image inspect rspec-runner > /dev/null 2>&1")
    puts "Building RSpec runner Docker image..."
    system("docker build --build-arg RUBY_VERSION=$DOCKER_RUBY_VERSION -t rspec-runner .")
  end

  puts "Running RSpec tests..."
  Dir.glob("spec/**/*_spec.rb") do |spec_file|
    puts "Running #{spec_file}..."
    system("docker run --rm rspec-runner bundle exec rspec #{spec_file}")

    # Exit the task if a test fails
    unless $?.success?
      abort("Test failed: #{spec_file}")
    end
  end
end