require 'test_helper'

class YaddlTest < ActiveSupport::TestCase
  test "defined" do
    assert_kind_of Module, Yaddl
  end
  test "create test model" do
    y = Yaddl::Yaddl.new
    y.markup = "TestModel"
    y.generate("--no-scaffolds --quiet")
    assert_file "app/models/test_model.rb", "class TestModel < ActiveRecord::Base

end
"
    assert_file "db/schema.yaml", "---
TestModel: {}
"
  end
end
