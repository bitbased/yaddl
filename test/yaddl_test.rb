require 'test_helper'

class YaddlTest < ActiveSupport::TestCase
  test "defined" do
    assert_kind_of Module, Yaddl
  end

  test "create test model" do
    y = Yaddl::Generator.new
    y.markup = "TestModel(name:string)
  =to_s{name}
  *ChildModel
  +RelatedModel
  ReferencedModel"
    y.generate("--no-scaffolds --quiet")
    y.generate("--migrations-only --quiet")
    assert_file "app/models/test_model.rb", "class TestModel < ActiveRecord::Base
  belongs_to :related_model
  has_one :referenced_model, dependent: :destroy
  has_many :child_models, dependent: :destroy

  attr_accessible :related_model_id
  attr_accessible :name

  accepts_nested_attributes_for :referenced_model
  accepts_nested_attributes_for :child_models

  # returns: string
  def to_s
    name
  end
end
"

    assert_file "app/models/related_model.rb", "class RelatedModel < ActiveRecord::Base
  has_many :test_models, dependent: :nullify

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
    child_models:
      dependent: destroy
      class_names:
      - ChildModel
  belongs_to:
    related_model:
      class_names:
      - RelatedModel
  has_one:
    referenced_model:
      dependent: destroy
      class_names:
      - ReferencedModel
ChildModel:
  belongs_to:
    test_model:
      class_names:
      - TestModel
RelatedModel:
  has_many:
    test_models:
      dependent: nullify
      class_names:
      - RelatedModel
ReferencedModel:
  belongs_to:
    test_model:
      class_names:
      - TestModel
"
  end
end
