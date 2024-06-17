task :default => :test

task :test do
  unless system("docker image inspect rspec-runner > /dev/null 2>&1")
    puts "Building RSpec runner Docker image..."

    ruby_version = ENV.has_key?("DOCKER_RUBY_VERSION") ? ENV["DOCKER_RUBY_VERSION"] : "3.3"
    system("docker build --build-arg RUBY_VERSION=#{ruby_version} -t rspec-runner .")
  end

  additional_options = ENV["debug"] ? "-it" : ""

  if ENV["file"]
    puts "Running RSpec test for #{ENV["file"]}..."
    system("docker run -v #{Dir.pwd}/lib:/app/lib -v #{Dir.pwd}/spec:/app/spec #{additional_options} --rm rspec-runner bundle exec rspec #{ENV["file"]} 2>&1")
  else
    puts "Running RSpec tests..."
    Dir.glob("spec/**/*_spec.rb") do |spec_file|
      puts "Running #{spec_file}..."
      system("docker run -v #{Dir.pwd}/lib:/app/lib -v #{Dir.pwd}/spec:/app/spec #{additional_options} --rm rspec-runner bundle exec rspec #{spec_file} 2>&1")

      # Exit the task if a test fails
      unless $?.success?
        abort("Test failed: #{spec_file}")
      end
    end
  end
end

task :access_container do
  puts "Accessing a new rspec-runner container..."
  system("docker run -it --rm -v #{Dir.pwd}/lib:/app/lib -v #{Dir.pwd}/spec:/app/spec --entrypoint /bin/bash rspec-runner")
end
