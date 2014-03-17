class RelatedModel < ActiveRecord::Base
  belongs_to :test_model

  attr_accessible :test_model_id
end
