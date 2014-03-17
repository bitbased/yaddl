$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "yaddl/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "yaddl"
  s.version     = Yaddl::VERSION
  s.authors     = ["Brant Wedel"]
  s.email       = ["brant@bitbased.net"]
  s.homepage    = "http://yaddl.org"
  s.summary     = "Yet Another Data Definition Language"
  s.description = "A concise data definition language and generator for active record with the ability to properly map model associations"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.0.0"

  s.add_development_dependency "sqlite3"
end
