require 'yaddl'

namespace :yaddl do
  desc "Print generated yaml ddl to console"
  task :review do
    y = Yaddl::Generator::load("#{Rails.root}/db/*.yaddl")
    y.review()
  end
  desc "Scaffold controllers views and models, skips migrations"
  task :scaffold do
    y = Yaddl::Generator::load("#{Rails.root}/db/*.yaddl")
    y.generate("--force --no-assets --skip-migration --helpers=false")
  end
  desc "Regenerate models, skips migrations"
  task :models do
    y = Yaddl::Generator::load("#{Rails.root}/db/*.yaddl")
    y.generate("--no-scaffolds")
  end
  desc "Generate migrations, models, controllers and views"
  task :generate do
    y = Yaddl::Generator::load("#{Rails.root}/db/*.yaddl")
    y.generate("--force --no-assets --helpers=false")
  end
end
