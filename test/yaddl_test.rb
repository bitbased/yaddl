require 'test_helper'

class YaddlTest < ActiveSupport::TestCase
  test "defined" do
    assert_kind_of Module, Yaddl
  end
  test "create test model" do
    y = Yaddl::Yaddl.new
    y.markup = "TestModel(name:string)
  =to_s{name}
  *RelatedModel"
    y.generate("--no-scaffolds --quiet")
    assert_file "app/models/test_model.rb", "class TestModel < ActiveRecord::Base
  has_many :related_models, dependent: :destroy

  attr_accessible :name

  accepts_nested_attributes_for :related_models

  # returns: string
  def to_s
    name
  end
end
"
    assert_file "app/models/related_model.rb", "class RelatedModel < ActiveRecord::Base
  belongs_to :test_model

  attr_accessible :test_model_id
end
"
    assert_file "db/schema.yaml", "---
TestModel:
  attributes:
    name:
      type: string
      primary_ref:
      - 
  methods:
    to_s:
      returns: string
      getter: name
  has_many:
    related_models:
      dependent: destroy
      class_names:
      - RelatedModel
RelatedModel:
  belongs_to:
    test_model:
      class_names:
      - TestModel
"
  end
end
