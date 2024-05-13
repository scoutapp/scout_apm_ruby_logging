task :default => :test

task :test do
  unless system("docker image inspect rspec-runner > /dev/null 2>&1")
    puts "Building RSpec runner Docker image..."
    system("docker build -t rspec-runner .")
  end

  puts "Running RSpec tests..."
  Dir.glob("spec/**/*_spec.rb") do |spec_file|
    puts "Running #{spec_file}..."
    system("docker run -v #{Dir.pwd}:/app --rm rspec-runner bundle exec rspec #{spec_file}")

    # Exit the task if a test fails
    unless $?.success?
      abort("Test failed: #{spec_file}")
    end
  end

  puts "All RSpec tests passed!"
end