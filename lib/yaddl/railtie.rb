require 'yaddl'
require 'rails'
module Yaddl
  class Railtie < Rails::Railtie
    railtie_name :yaddl

    rake_tasks do
      load "tasks/yaddl.rake"
    end
  end
end
