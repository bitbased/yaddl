# Yaddl

This project rocks and uses MIT-LICENSE.

# Usage

`gem 'yaddl'`

```
rake yaddl:models
rake yaddl:migrations
```

### Example Input

/db/schema.yaddl
```ruby
TestModel(name:string)
  =to_s{name}
  *RelatedModel
```

### Output

/app/models/test_model.rb
```ruby
class TestModel < ActiveRecord::Base
  has_many :related_models, dependent: :destroy

  attr_accessible :name

  accepts_nested_attributes_for :related_models

  # returns: string
  def to_s
    name
  end
end

```

/app/models/related_model.rb
```ruby
class RelatedModel < ActiveRecord::Base
  belongs_to :test_model

  attr_accessible :test_model_id
end

```

# Syntax

Legend:
- attribute:type - a model attribute; inline format will create 'primary references' for display ex: Model(name:string)
- =function - an property that is calculated not stored =value{ "ruby code" }
- ==setter - a property setter ex: ==value{ self.database_value = value; self.save }
- &cached - a value or model that is cached until a condition is met &cached{ 'condition summary' }
- Reference - has_one
- +Reference - belongs_to
- *Multiplicity - has_many
- **ManyToMany:OptionalBackingTable(join_model:attributes) - has and belongs to many
- attribute:*Reference - polymorphic association reference entry
- @Mixin - define or use mixin
- ___ - mixin name placeholder for named:@Mixin (these work in mixin code blocks and mixin attribute names)
- mmm/MMM(s) - model name placeholders (these work in any code blocks and mixin attribute names)
- {ruby_code} - ruby_code will be added to model
- !controller{ruby_code} - ruby_code will be added to controller
- !!{ruby_code} - unique ruby_code will be added to model only once
- if, unless, def, module, class - ruby code blocks (else and elsif are not currently supported at root)
- include, require, has_many, serialize, etc. - single line ruby methods

# Example Yaddl File

/db/photo_gallery.yaddl
```ruby
Gallery(name:string)
  @Descriptable
  @Commentable

  User

  *Photo(name:string)
    @Descriptable
    @Commentable

    User
    photographer:User # You can provide names for associations

    taken_at:datetime

    -image_src:text
    -thumb_src:text

    before_save :generate_thumbnail
    def generate_thumbnail
      # generate a thumbnail from image_drc for thumb_src
    end

User(email:string)
  !!{has_secure_password}
  name:string
  email:string
  password_digest:string
  attr_accessible :password

@Descriptable
  description:text

@Commentable
  User
  *Comment
    @Commentable # You can nest anything
```
