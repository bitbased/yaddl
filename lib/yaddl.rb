module Yaddl
  require "yaddl/railtie" if defined?(Rails)

  require "rails"
  require "rails/generators/migration"
class Generator

  attr_accessor :markup
  attr_accessor :models
  attr_accessor :quiet

  def self.load(filename)
    y = Yaddl::Generator.new
    if filename.include? "*"
      y.markup = ""
      Dir.glob(filename).each do |fn|
        y.markup += File.read(fn) + "\r\n"
      end
    else
      y.markup = File.read(filename)
    end
    y.models = {}
    y
  end

  def parse_attribute(attribute)
    at = attribute.split(/\:\*?/)
    name = at[0]
    type = "string"
    if at.count > 1
      type = at[1]
    else
      type = "integer" if name =~ /_id$|^id$|_nr$|^nr$|^number$|_number$/
      type = "datetime" if name =~ /_at$|^date$|_date$|_on$|_time$/
    end
    h = { 'name' => at[0], 'type' => type }
    h['default_type'] = at.count == 1
    h
  end

  def review
    parse
    puts("","--- DATA #{models.to_yaml}","") unless @quiet
  end

  def generate(options = "")
    @quiet = options.include?("--quiet")
    scaffolds(options)
  end

  def indent(string, count, char = ' ')
    string.gsub(/([^\n]*)(\n|$)/) do |match|
      last_iteration = ($1 == "" && $2 == "")
      line = ""
      line << (char * count) unless last_iteration || $1 == ""
      line << $1
      line << $2
      line
    end
  end

  def schema_diff

    puts("","--- MIGRATIONS ---","") unless @quiet

    schema = {}
    table_name = nil
    table_var = nil
    Dir.glob("#{Rails.root}/db/migrate/*.rb").sort.each do |file|
      File.read(file).each_line do |line|
        if line =~ /^\s*create_table \:([a-z_]+) do \|([a-z_])+\|.*$/
          table_name = line.sub(/^\s*create_table \:([a-z_]+) do \|([a-z_])+\|.*$/, '\1').strip
          table_var = line.sub(/^\s*create_table \:([a-z_]+) do \|([a-z_])+\|.*$/, '\2').strip
          schema[table_name] = {}
        elsif line =~ /^\s*end\s*$/
          table_name = nil
          table_var = nil
          down = false
        elsif line =~ /^\s*def down.*$/
        else
          if table_name
            if line =~ /^\s*#{table_var}\.([a-z_]+)(\s+|\()\:([a-z_]+).*$/
              attr_type = line.sub(/^\s*#{table_var}\.([a-z_]+)(\s+|\()\:([a-z_]+).*$/, '\1').strip
              attr_name = line.sub(/^\s*#{table_var}\.([a-z_]+)(\s+|\()\:([a-z_]+).*$/, '\3').strip

              if attr_type == "references"
                schema[table_name][attr_name+"_id"] ||= {}
                schema[table_name][attr_name+"_id"]["type"] = "integer"
                if line.include?("polymorphic: true")
                  schema[table_name][attr_name+"_type"] ||= {}
                  schema[table_name][attr_name+"_type"]["type"] = "string"
                  #add_index :sync_models, [:model_id, :model_type], name: "index_sync_models_on_model_id_and_model_type"
                end
                if line.include?("index: true")
                  schema[table_name]["_indexes"] = {}
                  if line.include?("polymorphic: true")
                    schema[table_name]["_indexes"]["#{attr_name}_id_and_#{attr_name}_type"] = {}
                  else
                    schema[table_name]["_indexes"]["#{attr_name}_id"] = {}
                  end
                end
              else
                schema[table_name][attr_name] ||= {}
                schema[table_name][attr_name]["type"] = attr_type
              end
            end
            if line =~ /^\s*#{table_var}\.timestamps\s*$/
              schema[table_name]["created_at"] ||= {}
              schema[table_name]["created_at"]["type"] = "datetime"
              schema[table_name]["updated_at"] ||= {}
              schema[table_name]["updated_at"]["type"] = "datetime"
            end
          else
            if !down
              if line =~ /^\s*add_index(\s+|\().*$/
                attr_table= line.sub(/^\s*[a-z_]+(\s+|\()\:([a-z_]+).*,.*\:([a-z_]+).*,.*\:([a-z_]+).*$/,'\2').strip
                index_column = line.sub(/^\s*[a-z_]+(\s+|\()\:([a-z_]+).*,.*\:([a-z_]+).*,.*\:([a-z_]+).*$/,'\3').strip

                schema[attr_table]["_indexes"] = {}
                schema[attr_table]["_indexes"][index_column] = {}
              end
              if line =~ /^\s*remove_column(\s+|\().*$/
                attr_table= line.sub(/^\s*[a-z_]+(\s+|\()\:([a-z_]+).*,.*\:([a-z_]+).*$/,'\2').strip
                attr_name = line.sub(/^\s*[a-z_]+(\s+|\()\:([a-z_]+).*,.*\:([a-z_]+).*$/,'\3').strip
                schema[attr_table] ||= {}
                schema[attr_table].delete(attr_name)
              end
              if line =~ /^\s*(add_column|change_column)(\s+|\().*$/
                #add_column(table_name, column_name, type, options)
                #change_column(table_name, column_name, type, options)
                attr_table= line.sub(/^\s*[a-z_]+(\s+|\()\:([a-z_]+).*,.*\:([a-z_]+).*,.*\:([a-z_]+).*$/,'\2').strip
                attr_name = line.sub(/^\s*[a-z_]+(\s+|\()\:([a-z_]+).*,.*\:([a-z_]+).*,.*\:([a-z_]+).*$/,'\3').strip
                attr_type = line.sub(/^\s*[a-z_]+(\s+|\()\:([a-z_]+).*,.*\:([a-z_]+).*,.*\:([a-z_]+).*$/,'\4').strip

                schema[attr_table] ||= {}
                attr_changed = !!schema[attr_table][attr_name]
                schema[attr_table][attr_name] ||= {}
                schema[attr_table][attr_name]["type"] = attr_type
              end
            end
          end
        end
      end
    end


    models.reject{ |k,v| k[0] == "@"}.each do |name,model|
      model['has_one'] ||= {}
      model['has_many'] ||= {}
      model['belongs_to'] ||= {}
      model['attributes'] ||= {}
      model['methods'] ||= {}
      model['code'] ||= {}
      model['code']['top'] ||= []
      model['code']['before'] ||= []
      model['code']['after'] ||= []
      model['code']['controller'] ||= []

      table_name = name.pluralize.underscore.downcase
      next unless schema[table_name]

      attrs = {}
      model['attributes'].each do |k,v|
        attrs[k] ||= {}
        attrs[k]['type'] = v['type'].sub(/yaml|hash|object|cache/i, "text")
      end
      model['belongs_to'].each do |k,v|
        attrs[k+"_id"] ||= {}
        attrs[k+"_id"]['type'] = 'integer'
        if v['polymorphic']
          attrs[k+"_type"] ||= {}
          attrs[k+"_type"]['type'] = 'string'
        end
      end

      changes = []
      summary = []
      verb = ""
      attrs.each do |k,v|
        if schema[table_name][k]
          if schema[table_name][k]['type'] != v['type']
            verb = "Change" if verb == ""
            verb = "Update" if verb == "Add"
            summary << k
            changes << "change_column :#{table_name}, :#{k}, :#{v['type']}"
          end
        else
          verb = "Add" if verb == ""
          verb = "Update" if verb == "Change"
          summary << k
          changes << "add_column :#{table_name}, :#{k}, :#{v['type']}"
        end
      end

      summary = [summary.first,"others"] if summary.count > 2
      summary = verb + summary.join("_and_").camelize
      v2 = verb == "Add" ? "To" : "On"
      if changes.count > 0
        index = ""
        while Dir.glob("#{Rails.root}/db/migrate/*_#{summary}#{v2}#{name.pluralize}#{index}".underscore.downcase+".rb").count > 0
          index = 1 if index = ""
          index += 1
        end

        puts DateTime.now.strftime("%Y%m%d%H%M%S") + "_#{summary}#{v2}#{name.pluralize}#{index}".underscore.downcase + ".rb"
        File.write("#{Rails.root}/db/migrate/" + DateTime.now.strftime("%Y%m%d%H%M%S") + "_#{summary}#{v2}#{name.pluralize}#{index}".underscore.downcase+".rb", "class #{summary}#{v2}#{ name.pluralize }#{index} < ActiveRecord::Migration
  def change
    #{changes.join("\n    ")}
  end
end
")
      end
    end

  end

  def scaffolds(options = "")
    parse

    schema_diff

    puts("","--- SCAFFOLDS ---","") unless @quiet

    models.reject{ |k,v| k[0] == "@"}.each do |name,model|
      model['has_one'] ||= {}
      model['has_many'] ||= {}
      model['belongs_to'] ||= {}
      model['attributes'] ||= {}
      model['methods'] ||= {}
      model['code'] ||= {}
      model['code']['top'] ||= []
      model['code']['before'] ||= []
      model['code']['after'] ||= []
      model['code']['controller'] ||= []

      sc = "rails g scaffold #{name} " + model['attributes'].map{ |k,v| k + ':' + v['type'].sub(/yaml|hash|object|cache/i,"text") }.join(' ') + " " + model['belongs_to'].map{ |k,v| k + ':references' + (v['polymorphic'] ? "{polymorphic}" : "") }.join(' ')
      puts("model: #{sc}") unless @quiet
      `#{sc} #{options}`

      File.delete("#{Rails.root}/app/views/#{name.underscore.pluralize}/index.json.jbuilder")
      sc = "rails g scaffold #{name} " + model['methods'].reject{ | k, v| !v['primary_ref'] || v['hidden'] }.map{ |k,v| k + ':' + v['type'].to_s.sub(/yaml|hash|object|cache/i,"text").sub(/^$/,"string") }.join(' ') + " " + model['attributes'].reject{ | k, v| v['hidden'] }.map{ |k,v| k + ':' + v['type'].sub(/yaml|hash|object|cache/i,"text") }.join(' ') + " " + model['belongs_to'].reject{ | k, v| v['hidden'] }.map{ |k,v| k + ':references' + (v['polymorphic'] ? "{polymorphic}" : "") }.join(' ')
      puts("index: #{sc}") unless @quiet
      `#{sc} #{options.gsub("--force","")} --skip --no-migrations`

      File.delete("#{Rails.root}/app/views/#{name.underscore.pluralize}/show.json.jbuilder")
      File.delete("#{Rails.root}/app/views/#{name.underscore.pluralize}/show.html.erb")
      sc = "rails g scaffold #{name} " + model['methods'].reject{ | k, v| k == "to_s" || v['hidden'] }.map{ |k,v| k + ':' + v['type'].to_s.sub(/yaml|hash|object|cache/i,"text").sub(/^$/,"string") }.join(' ') + " " + model['attributes'].reject{ | k, v| v['hidden'] }.map{ |k,v| k + ':' + v['type'].sub(/yaml|hash|object|cache/i,"text") }.join(' ') + " " + model['belongs_to'].reject{ | k, v| v['hidden'] }.map{ |k,v| k + ':references' + (v['polymorphic'] ? "{polymorphic}" : "") }.join(' ')
      puts("show: #{sc}") unless @quiet
      `#{sc} #{options.gsub("--force","")} --skip --no-migrations`

      File.delete("#{Rails.root}/app/views/#{name.underscore.pluralize}/_form.html.erb")
      sc = "rails g scaffold #{name} " + model['attributes'].reject{ | k, v| v['hidden'] }.map{ |k,v| k + ':' + v['type'].sub(/yaml|hash|object|cache/i,"text") }.join(' ') + " " +
        model['belongs_to'].reject{ |k, v| v['hidden'] }.map{ |k,v| k + ':references' + (v['polymorphic'] ? "{polymorphic}" : "") }.join(' ')
      puts("form: #{sc}") unless @quiet
      `#{sc} #{options.gsub("--force","")} --skip --no-migrations`
    end if !options.include?("--no-scaffold") && !options.include?("--migrations-only")

    models.reject{ |k,v| k[0] == "@"}.each do |name,model|
      model['has_one'] ||= {}
      model['has_many'] ||= {}
      model['belongs_to'] ||= {}
      model['attributes'] ||= {}
      model['methods'] ||= {}
      model['code'] ||= {}
      model['code']['top'] ||= []
      model['code']['before'] ||= []
      model['code']['after'] ||= []
      model['code']['controller'] ||= []
      sc = "rails g model #{name} " + model['attributes'].map{ |k,v| k + ':' + v['type'].sub(/yaml|hash|object|cache/i,"text") }.join(' ') + " " + model['belongs_to'].map{ |k,v| k + ':references' + (v['polymorphic'] ? "{polymorphic}" : "") }.join(' ')
      puts("migration: cd #{Rails::root} && #{sc} --skip --no-test-framework") unless @quiet
      `cd #{Rails::root} && #{sc} --skip --no-test-framework`
    end if options.include?("--migrations-only")


    schema_diff() unless options.include?("--migrations-only")
    #$ rails generate migration AddPartNumberToProducts part_number:string:index
    #sc = "rails g model #{name} " + model['attributes'].map{ |k,v| k + ':' + v['type'].sub(/yaml|hash|object|cache/i,"text") }.join(' ') + " " + model['belongs_to'].map{ |k,v| k + ':references' + (v['polymorphic'] ? "{polymorphic}" : "") }.join(' ')

    if options.include?("--migrations-only")
      cleanup(ddl: true, mixins: false)
      File.open("#{Rails.root}/db/schema.yaml", "w") do |f|
        f.write models.to_yaml
      end
      puts("","--- DATA #{models.to_yaml}","") unless @quiet
      return
    end

    models.reject{ |k,v| k[0] == "@"}.each do |name,model|
      model['has_one'] ||= {}
      model['has_many'] ||= {}
      model['belongs_to'] ||= {}
      model['attributes'] ||= {}
      model['methods'] ||= {}
      model['code'] ||= {}
      model['code']['top'] ||= []
      model['code']['before'] ||= []
      model['code']['after'] ||= []
      model['code']['controller'] ||= []

      file = "class #{name} < ActiveRecord::Base"
      model['code']['top'].each do |code|
        file += "\n  #{code.each_line{|l| "  " + l}}"
      end
      file += "\n" if model['code']['top'].length > 0

      model['belongs_to'].each do |k,assoc|
        file += "\n  belongs_to :#{k}"
        file += ", #{assoc.reject{|k,v| k == "hidden" || k == "class_names" || (k == "class_name" && assoc['polymorphic'])}.map{|k,v| v == true || v == false || v.is_a?(Array) || v.downcase == v ? "#{k}: #{":" unless v == true || v == false || v.is_a?(Array) }#{v}" : "#{k}: \"#{v}\"" }.join(', ')}" if assoc.reject{|k,v| k == "hidden" || k == "class_names" || (k == "class_name" && assoc['polymorphic'])}.count > 0
      end

      model['has_one'].each do |k,assoc|
        file += "\n  has_one :#{k.underscore}"
        file += ", #{assoc.reject{|k,v| k == "hidden" || k == "class_names"}.map{|k,v| v == true || v == false || v.is_a?(Array) || v.downcase == v ? "#{k}: #{":" unless v == true || v == false || v.is_a?(Array) }#{v}" : "#{k}: \"#{v}\"" }.join(', ')}" if assoc.reject{|k,v| k == "hidden" || k == "class_names"}.count > 0
      end

      model['has_many'].reject{|k,v| v['polymorphic']}.each do |k,assoc|
        file += "\n  has_many :#{k.pluralize.underscore}"
        file += ", #{assoc.reject{|k,v| k == "hidden" || k == "polymorphic" || k == "class_names"}.map{|k,v| v == true || v == false || v.is_a?(Array) || v.downcase == v ? "#{k}: #{":" unless v == true || v == false || v.is_a?(Array) }#{v}" : "#{k}: \"#{v}\"" }.join(', ')}" if assoc.reject{|k,v| k == "hidden" || k == "polymorphic" || k == "class_names"}.count > 0
      end
      model['has_many'].select{|k,v| v['polymorphic']}.each do |k,assoc|
        file += "\n  has_many :#{k.pluralize.underscore}"
        file += ", #{(assoc.reject{|k,v| k == "hidden" || k == "polymorphic" || k == "class_names"}.map{|k,v| v == true || v == false || v.is_a?(Array) || v.downcase == v ? "#{k}: #{":" unless v == true || v == false || v.is_a?(Array) }#{v}" : "#{k}: \"#{v}\"" }+["as: :#{assoc['foreign_key'].gsub(/_id$/,"")}"]).join(', ')}" if assoc.reject{|k,v| k == "hidden" || k == "polymorphic" || k == "class_names"}.count > 0
      end

      file += "\n" # if model['belongs_to'].count + model['attributes'].count > 0
      #file += "\n  attr_accessible :created_at, :updated_at"
      file += "\n  attr_accessible #{model['belongs_to'].map{ |k,v| ":#{k}_id" }.join(', ')}" if model['belongs_to'].count > 0
      file += "\n  attr_accessible #{model['belongs_to'].reject{ |k,v| !v['polymorphic'] }.map{ |k,v| ":#{k}_type" }.join(', ')}" if model['belongs_to'].reject{ |k,v| !v['polymorphic'] }.count > 0
      file += "\n  attr_accessible #{model['attributes'].map{ |k,v| ":#{k}" }.join(', ')}" if model['attributes'].count > 0

      file += "\n" if model['has_many'].reject{|k,v| v['dependent'] != 'destroy' }.count + model['has_one'].reject{|k,v| v['dependent'] != 'destroy' }.count > 0
      file += "\n  accepts_nested_attributes_for #{model['has_one'].reject{|k,v| v['dependent'] != 'destroy' }.map{ |k,v| ":#{k}" }.join(', ')}" if model['has_one'].reject{|k,v| v['dependent'] != 'destroy' }.count > 0
      file += "\n  accepts_nested_attributes_for #{model['has_many'].reject{|k,v| v['dependent'] != 'destroy' }.map{ |k,v| ":#{k}" }.join(', ')}" if model['has_many'].reject{|k,v| v['dependent'] != 'destroy' }.count > 0

      file += "\n" if model['code']['before'].length > 0
      model['code']['before'].each do |code|
        file += "\n#{indent(code, 2)}"
      end

      model['methods'].each do |k,assoc|
        if assoc['getter']
          file += "\n"
          assoc.each do |k,v|
            file += "\n  # #{k}: #{v}" if k != 'getter' && k != 'setter' && k != 'takes'
          end
          file += "\n  def #{k}"
          file += "\n    #{assoc['getter']}"
          file += "\n  end"
        end
        if assoc['setter']
          file += "\n"
          assoc.each do |k,v|
            file += "\n  # #{k}: #{v}" if k != 'getter' && k != 'setter' && k != 'returns'
          end
          file += "\n  def #{k}=(value)"
          file += "\n    #{assoc['setter']}"
          file += "\n  end"
        end
      end

      file += "\n" if model['code']['after'].length > 0
      model['code']['after'].each do |code|
        file += "\n#{indent(code, 2)}"
      end

      file += "\nend\n"

      puts("app/models/#{name.underscore}.rb") unless @quiet
      File.open("#{Rails.root}/app/models/#{name.underscore}.rb", "w") do |f|
        f.write(file)
      end

      next if options.include?("--no-scaffold")

      puts("app/controllers/#{name.underscore.pluralize}_controller.rb") unless @quiet


      file = File.read("#{Rails.root}/app/controllers/#{name.underscore.pluralize}_controller.rb")
      file.sub!("  # GET /#{name.underscore.pluralize}
  # GET /#{name.underscore.pluralize}.json
  def index
    @#{name.underscore.pluralize} = #{name}.all
  end", "#{model['code']['controller'].map{|line| "  #{line}
"}.join}#{"
" if model['code']['controller'].length > 0}  # GET /#{name.underscore.pluralize}
  # GET /#{name.underscore.pluralize}.json
  def index
    @#{name.underscore.pluralize} = #{name}.all#{ model['belongs_to'].map do |attr_name, assoc| "
    if params[:#{attr_name.underscore}_id]
      @#{name.underscore.pluralize} = @#{name.underscore.pluralize}.where(#{attr_name.underscore}_id: params[:#{attr_name.underscore}_id])
    end
" end.join }#{ "
" if true || model['belongs_to'].count > 0 }  end")


      file.sub!("  # GET /#{name.underscore}/1
  # GET /#{name.underscore}/1.json
  def show
  end","  # GET /#{name.underscore}/1
  # GET /#{name.underscore}/1.json
  def show
    @#{name.underscore} = #{name}.new#{ model['belongs_to'].map do |attr_name, assoc| "
    if params[:#{attr_name.underscore}_id]
      @#{name.underscore}.#{attr_name.underscore}_id = params[:#{attr_name.underscore}_id]
    end
" end.join }  end")


      file.sub!("  # GET /#{name.underscore.pluralize}/new
  def new
    @#{name.underscore} = #{name}.new
  end","  # GET /#{name.underscore.pluralize}/new
  def new
    @#{name.underscore} = #{name}.new#{ model['belongs_to'].map do |attr_name, assoc| "
    if params[:#{attr_name.underscore}_id]
      @#{name.underscore}.#{attr_name.underscore}_id = params[:#{attr_name.underscore}_id]
    end
" end.join }  end")



      File.open("#{Rails.root}/app/controllers/#{name.underscore.pluralize}_controller.rb", "w") do |f|
        f.write(file)
      end

      puts("app/views/#{name.underscore.pluralize}/index.html.erb") unless @quiet
      File.open("#{Rails.root}/app/views/#{name.underscore.pluralize}/index.html.erb", "w") do |f|

        names = model['attributes'].reject{ |k,v| v['hidden'] }.merge(model['methods'].reject{ |k,v| v['hidden'] }.merge(model['belongs_to'].reject{ |k,v| v['hidden'] })).reject{ | k, v| !v['primary_ref'] }
        names = model['attributes'].reject{ |k,v| v['hidden'] }.merge(model['belongs_to'].reject{ |k,v| v['hidden'] }) if names.count == 0

        f.write "<h1>Listing #{name.titleize.pluralize}</h1>

<table>
  <thead>
    <tr>
#{ names.map do |k, v|
"      <th>#{k.titlecase}</th>
"
end.join }      <th></th>
      <th></th>
      <th></th>
    </tr>
  </thead>

  <tbody>
    <% @#{name.underscore.pluralize}.each do |#{name.underscore}| %>
      <tr>
#{ names.map do |k, v|
"      <th><%= #{name.underscore}.#{k.underscore} %></th>
"
end.join }        <td><%= link_to 'Show', #{name.underscore} %></td>
        <td><%= link_to 'Edit', edit_#{name.underscore}_path(#{name.underscore}) %></td>
        <td><%= link_to 'Destroy', #{name.underscore}, method: :delete, data: { confirm: 'Are you sure?' } %></td>
      </tr>
    <% end %>
  </tbody>
</table>

<br>

<%= link_to 'New #{name.titleize}', url_for([:new, #{(model['belongs_to'].map{ |k,v| "@" + k.underscore } + [":#{name.underscore}"] ).join(', ')}]) %>
"
      end






      puts("app/views/#{name.underscore.pluralize}/show.html.erb") unless @quiet
      File.open("#{Rails.root}/app/views/#{name.underscore.pluralize}/show.html.erb", "w") do |f|

        names = model['attributes'].reject{ |k,v| v['hidden'] }.merge(model['methods'].reject{ |k,v| v['hidden'] }.reject{ |k,v| v['returns'].to_s.downcase != v['returns'].to_s }).reject{ |name, v| name == "to_s"}

        f.write "<p id=\"notice\"><%= notice %></p>

<h1>#{name.titleize}#{ " <%= @"+name.underscore + " %>" if model['methods'].reject{ |k,v| k != "to_s" }.count > 0 }</h1>

#{names.map do |attr_name, v|
"<p>
  <strong>#{attr_name.titleize}:</strong>
  <%= @#{name.underscore}.#{attr_name.underscore} %>
</p>

" end.join }#{
  model['belongs_to'].merge(model['methods'].reject{ |k,v| v['returns'].to_s.downcase == v['returns'].to_s }).map do |attr_name,v|
"<p>
  <strong>#{attr_name.titleize}:</strong>
  <%= link_to @#{name.underscore}.#{attr_name.underscore}, @#{name.underscore}.#{attr_name.underscore}  %>
</p>

" end.join }<%= link_to 'Edit', edit_#{name.underscore}_path(@#{name.underscore}) %> |
<%= link_to 'Back', url_for([#{(model['belongs_to'].map{ |k,v| "@" + k.underscore } + [":#{name.underscore.pluralize}"]).join(', ')}]) rescue #{name.underscore.pluralize}_path %>
#{ model['has_many'].map do |model,v|
"
<div class=\"has-many-index\">
  <% notice = nil %>
  <% @#{(v['class_name'] || model).underscore.downcase.pluralize} = @#{name.underscore}.#{model.underscore.pluralize} %>
  <%= render template: \"#{(v['class_name'] || model).underscore.downcase.pluralize}/index\" %>
</div>" end.join }
"
      end


      puts("app/views/#{name.underscore.pluralize}/_form.html.erb") unless @quiet
      f_content = File.read("#{Rails.root}/app/views/#{name.underscore.pluralize}/_form.html.erb")
      File.open("#{Rails.root}/app/views/#{name.underscore.pluralize}/_form.html.erb", "w") do |f|

        model['belongs_to'].each do |k,assoc|
          if assoc['polymorphic']
            f_content.gsub!("    <%= f.association :#{k} %>", "    <%= f.input :#{k}_type, collection: #{assoc['class_names']} %><%= f.association :#{k}, collection: #{assoc['class_names'].map{ |word| "#{word}.all" }.join(" + ")} %>")
          end
          #file += ", #{assoc.reject{|k,v| k == "hidden" || k == "class_names" || (k == "class_name" && assoc['polymorphic'])}.map{|k,v| v == true || v == false || v.is_a?(Array) || v.downcase == v ? "#{k}: #{":" unless v == true || v == false || v.is_a?(Array) }#{v}" : "#{k}: \"#{v}\"" }.join(', ')}" if assoc.reject{|k,v| k == "hidden" || k == "class_names" || (k == "class_name" && assoc['polymorphic'])}.count > 0
        end

        f.write f_content
      end


      #puts "rails g scaffold #{name} " + model['attributes'].map{ |k,v| k + ':' + v['type'].sub(/yaml|hash|object|cache/i,"text") }.join(' ') + " " + model['has_one'].map{ |k,v| k + ':references' + (v['polymorphic'] ? "{polymorphic}" : "") }.join(' ') + " #{options}"
    end

    cleanup(ddl: true, mixins: false)

    File.open("#{Rails.root}/db/schema.yaml", "w") do |f|
      f.write models.to_yaml
    end

    puts("","--- DATA #{models.to_yaml}","") unless @quiet
  end

  def parse
    #puts ""
    #puts "--- PARSE ---"
    self.models = {}
    stack = [nil]
    depth = 0
    self.markup.gsub(/.---..*/m,"").lines.each do |line|
      next if (line.strip == "" || line.strip.start_with?("#")) && !@multiline
      parse_line(line, self.models, stack, depth)
    end


    lines = []
    models.select{ |k,v| k[0] != "@"}.each do |model,v0|

      if models["@Default"] != nil && (!models['has_many'] || models['has_many']['@defaults'] != nil)
        name = "@default"
        type = "@Default"
        if name[0] == "@"
          puts("#{model} > #{type}") unless @quiet
          v0['includes'] ||= []
          v0['includes'] << type
          v0['includes'].uniq!
          models[type]['ddl'].select{|v| v.start_with?(type + " > ")}.each do |ddl|
            line = ddl.sub("#{type} > ","")
            line.gsub!("___","")
            puts("  #{line}") unless @quiet
            lines << {'model' => model, 'content' => line}
          end
        end
      end

      v0['belongs_to'].each do |k,v1|
        v1['class_names'].each do |v|
          if v[0] == "@"
            name = k
            name += "_" unless name.end_with?("_")
            type = v
            if name[0] != "@"
              next if name.include? "___"
              puts("#{model} > #{name}:#{type}") unless @quiet
              v0['includes'] ||= []
              v0['includes'] << "#{name}:#{type}"
              v0['includes'].uniq!
              models[type]['ddl'].select{|v| v.start_with?(type + " > ")}.each do |ddl|
                line = ddl.sub("#{type} > ","")
                #name2 = line.sub(/ *[\+\-\*\=\&]*([@A-Za-z0-9_]+).*/,'\1')
                #data_type = nil
                #data_type = line.sub(/^ *[\+\-\*\=\&]*[@A-Za-z0-9_]+\:?([@A-Za-z0-9_]+).*/,'\1') if line =~ /^ *[\+\-\*\=\&]*[@A-Za-z0-9_]+\:[@A-Za-z0-9_]+.*/
                #flags = line.sub(/\s*([\-\+\*\&\=]+).*/,'\1') if line =~ /\s*([\-\+\*\&\=]+).*/
                line.gsub!("___",name)
                puts("  #{line}") unless @quiet
                lines << {'model' => model, 'content' => line}
              end
            end
          end
        end
      end if v0['belongs_to']

      v0['has_one'].each do |k,v1|
        v1['class_names'].each do |v|
          if v[0] == "@"
            name = k
            type = v
            if name[0] == "@"
              puts("#{model} > #{type}") unless @quiet
              v0['includes'] ||= []
              v0['includes'] << type
              v0['includes'].uniq!
              models[type]['ddl'].select{|v| v.start_with?(type + " > ")}.each do |ddl|
                line = ddl.sub("#{type} > ","")
                line.gsub!("___","")
                puts("  #{line}") unless @quiet
                lines << {'model' => model, 'content' => line}
              end
            end
          end
        end
      end if v0['has_one']
    end

    cleanup(ddl: true, mixins: false)

    lines.each do |line|
      stack = [line['model'],nil,nil,nil,nil]
      depth = 1
      parse_line(line['content'], models, stack, depth)
    end

    #throw "DDL"
    puts("","--- DDL ---","") unless @quiet

    models
  end

  def cleanup(options = {})

    options[:ddl] ||= false
    options[:mixins] ||= false

    #models.reject!{ |k,v| k[0] == "@"}
    models.each do |model,v0|

      v0.delete('ddl') if options[:ddl] == true

      v0['has_one'].select{true}.each do |k,v1|
        v0['has_one'].delete(k) if k[0] == "@"
        v1['class_names'].select{true}.each do |v|
          if v[0] == "@"
            v0['has_one'].delete(k)
            break
          end
        end
      end if v0['has_one']
      v0.delete('has_one') if v0['has_one'] == {}

      v0['has_many'].select{true}.each do |k,v1|
        v0['has_many'].delete(k) if k[0] == "@"
        v1['class_names'].select{true}.each do |v|
          if v[0] == "@"
            v0['has_many'].delete(k)
            break
          end
        end
      end if v0['has_many']
      v0.delete('has_many') if v0['has_many'] == {}

      v0['belongs_to'].select{true}.each do |k,v1|
        v0['belongs_to'].delete(k) if k[0] == "@"
        v1['class_names'].select{true}.each do |v|
          if v[0] == "@"
            v0['belongs_to'].delete(k)
            break
          end
        end
      end if v0['belongs_to']
      v0.delete('belongs_to') if v0['belongs_to'] == {}

      v0.delete('attributes') if v0['attributes'] == {}
      v0.delete('methods') if v0['methods'] == {}

      if v0['code']
        v0['code'].select{true}.each do |k,v|
          v0['code'].delete(k) if v0['code'][k] == []
        end
        v0.delete('code') if v0['code'] == {}
      end

    end

  end


  def parse_line(line, models, stack, depth)
    spaces = line[/\A */].size

    @multiline ||= false
    unless @multiline
      if line.strip =~ /^(def|module|class|if|unless) / || line.strip =~ / do \|.+\|$/ || line.strip =~ / do$/
        @multiline = true
        @multiline_spaces = spaces
        @multiline_end = /^#{" " * @multiline_spaces}end$/
        @multiline_buffer = line[@multiline_spaces..line.length]
        return
      elsif line.strip =~ /^[a-z_]+ |^acts_as_.*/
        if line.strip =~ /^include |^require |^extend |^acts_as_[a-z_]+/
          line = "!top{#{line.strip}}"
        else
          line = "!!{#{line.strip}}"
        end
      end
    else
      if line.strip == ""
        @multiline_buffer += "\n"
      else
        @multiline_buffer += line[@multiline_spaces..line.length]
      end
      if line =~ @multiline_end
        line = "!after{" + @multiline_buffer.strip + "}"
        spaces = @multiline_spaces
        @multiline = false
      else
        return
      end
    end

    line.strip!

    return if line == ""

    depth = spaces / 2
    parent = nil
    parent = stack[depth]
    if parent && parent[0] != "@"
      line.gsub!("MMMs",parent.pluralize)
      line.gsub!("MMMS",parent.pluralize)
      line.gsub!("MMM",parent)
      line.gsub!("mmms",parent.underscore.downcase.pluralize)
      line.gsub!("mmm",parent.underscore.downcase)
    end

    if line[0] == "{"

      depth = spaces / 2

      parent = nil
      parent = stack[depth]

      models[parent] ||= {} if parent

      models[parent]['ddl'] ||= [] if parent
      models[parent]['ddl'] << (parent ? "#{parent} > " : '') + line if parent

      models[parent]['code'] ||= {} if parent
      models[parent]['code']['after'] ||= [] if parent
      models[parent]['code']['after'] << line[1..-2] if parent

      return
    elsif line[0] == "!"

      depth = spaces / 2

      parent = nil
      parent = stack[depth]

      models[parent] ||= {} if parent

      models[parent]['ddl'] ||= [] if parent
      models[parent]['ddl'] << (parent ? "#{parent} > " : '') + line if parent

      place = line.sub(/^\!\!?([a-zA-Z_]*)\{.*/m,'\1').strip
      place = 'before' if place == ""
      _unique = line[1] == "!"
      line.sub!(line.sub(/^(\!\!?[a-zA-Z_]*)\{.*/m,'\1'),'')
      models[parent]['code'] ||= {} if parent
      models[parent]['code'][place] ||= [] if parent
      if line[0] == "{"
        if !_unique || !models[parent]['code'][place].include?(line[1..-2])
          models[parent]['code'][place] << line[1..-2]
        end
      else
        if !_unique || !models[parent]['code'][place].include?(line)
          models[parent]['code'][place] << line
        end
      end

      return
    end

    name = line.sub(/ *[\+\-\*\=\&]*([@A-Za-z0-9_]+).*/,'\1')
    data_type = nil
    polymorphic = false

    data_type = line.sub(/^ *[\+\-\*\=\&]*[@A-Za-z0-9_]+\:?([@A-Za-z0-9_]+).*/,'\1') if line =~ /^ *[\+\-\*\=\&]*[@A-Za-z0-9_]+\:[@A-Za-z0-9_]+.*/
    if line =~ /^ *[\+\-\*\=\&]*[@A-Za-z0-9_]+\:\*[@A-Za-z0-9_]+.*/
      data_type = line.sub(/^ *[\+\-\*\=\&]*[@A-Za-z0-9_]+\:\*?([@A-Za-z0-9_]+).*/,'\1')
      polymorphic = true
    end

    type = "attribute"
    type = "model" if name[0] =~ /[@A-Z]/
    type = "model" if data_type && data_type[0] =~ /[@A-Z]/

    if data_type && type == "model"
      model = data_type
    elsif type == "model"
      model = name
    end
    model = name if type == "model" && model == nil

    attributes = []
    attributes = line.sub(/.*\((.*)\).*/,'\1').split(/\s/) if line =~ /.*\((.*)\).*/

    data = nil
    data = Regexp.last_match[0][1..-2] if line =~ /[\{].*[\}]/xms

    flags = nil
    flags = line.sub(/\s*([\-\+\*\&\=]+).*/,'\1') if line =~ /\s*([\-\+\*\&\=]+).*/

    multiplicity = "has_one"
    multiplicity = "has_many" if flags == "*" || flags == ".*" || flags == "*." || flags == "-*" || flags == "*-"
    multiplicity = "has_and_belongs_to_many" if flags == "**" || flags == "+**" || flags == "**+"
    multiplicity = "belongs_to" if flags == "+" || flags == "-+" || flags == "+-" || flags == ".+" || flags == "+."
    multiplicity = "has_many" if flags == "*+" || flags == "+*" || flags == "++"

    dependent = "destroy"
    dependent = "nullify" if flags == "*+" || flags == "+*" || flags == "++" || flags == "+"
    dependent = nil if flags == "**+" || flags == "+**"

    hidden = false
    hidden = true if flags == "-" || flags == "-+" || flags == "+-"
    #read_only = false
    #read_only = true if flags == "." || flags == ".+"
    type = "method" if flags == "="
    type = "property" if flags == "=="
    type = "cached" if flags == "&" && type != "model"

    depth = spaces / 2
    stack[depth+1] = model if type == "model"

    parent = nil
    parent = stack[depth]

    #puts "#{parent}#{flags}#{"." if !flags && parent}#{name}:#{model}#{"(" + attributes.join(' ') + ")" if attributes.count > 0}" if parent || attributes.count > 0

    models[parent] ||= {} if parent
    models[model] ||= {} if type == "model"

    models[parent]['ddl'] ||= [] if parent
    models[parent]['ddl'] << (parent ? "#{parent} > " : '') + line if parent
    models[model]['ddl'] ||= [] if model
    models[model]['ddl'] << "~" + (parent ? "#{parent} > " : '') + line if model

    unless (type == "method" || type == "property" || type == "attribute")
      attributes.each do |attribute|

        _flags = attribute.sub(/([\-\+\*\&\=]+).*/,'\1') if attribute =~ /([\-\+\*\&\=]+).*/
        _mode = 'attributes'
        _mode = 'methods' if _flags == "="
        _hidden = false
        _hidden = true if _flags == "-"

        at = parse_attribute(attribute.sub(/^[\-\=]+/,""))
        models[model][_mode] ||= {}
        models[model][_mode][at['name']] ||= {}
        if !models[model][_mode][at['name']]['type'] || !at['default_type']
          models[model][_mode][at['name']]['type'] = at['type']
        end
        models[model][_mode][at['name']]['hidden'] = true if _hidden
        models[model][_mode][at['name']]['primary_ref'] ||= []
        models[model][_mode][at['name']]['primary_ref'] << parent
      end
    end

    if parent && (type == "attribute" || type == "cached")
      at = parse_attribute("#{name}#{":" + data_type if data_type}")
      models[parent]['attributes'] ||= {}
      models[parent]['attributes'][at['name']] = {}
      models[parent]['attributes'][at['name']]['hidden'] = true if hidden
      if !models[parent]['attributes'][at['name']]['type'] || !at['default_type']
        models[parent]['attributes'][at['name']]['type'] = at['type']
      end
    end

    if parent && (type == "method" || type == "property")
      at = parse_attribute("#{name}#{":" + data_type if data_type}")
      models[parent]['methods'] ||= {}
      models[parent]['methods'][at['name']] ||= {}
      if type == "method"
        models[parent]['methods'][at['name']]['returns'] = at['type']
        unless models[parent]['methods'][at['name']]['setter']
          models[parent]['methods'][at['name']]['getter'] = data.to_s
        else
          models[parent]['methods'][at['name']]['getter'] += "\n    " + data if data
        end
      else
        models[parent]['methods'][at['name']]['takes'] = at['type']
        unless models[parent]['methods'][at['name']]['getter']
          models[parent]['methods'][at['name']]['setter'] = data.to_s
        else
          models[parent]['methods'][at['name']]['setter'] += "\n    " + data if data
        end
      end
    end

    if type == "model" && parent
      if multiplicity == "has_many"
        models[parent]['has_many'] ||= {}
        models[parent]['has_many'][name.pluralize.underscore] ||= (model && name != model) ? { 'class_name' => model } : {}
        models[parent]['has_many'][name.pluralize.underscore]['dependent'] = dependent if dependent
        models[parent]['has_many'][name.pluralize.underscore]['foreign_key'] = name.underscore + "_id" if model && name != model
        models[parent]['has_many'][name.pluralize.underscore]['polymorphic'] = true if polymorphic

        models[parent]['has_many'][name.pluralize.underscore]['class_names'] ||= []
        models[parent]['has_many'][name.pluralize.underscore]['class_names'] << model
        models[parent]['has_many'][name.pluralize.underscore]['class_names'].uniq!

        models[model]['belongs_to'] ||= {}
        if model && name != model
          models[model]['belongs_to'][name.pluralize.underscore] ||= { 'class_name' => parent }
          models[model]['belongs_to'][name.pluralize.underscore]['hidden'] = true if hidden
          models[model]['belongs_to'][name.pluralize.underscore]['polymorphic'] = true if polymorphic

          models[model]['belongs_to'][name.pluralize.underscore]['class_names'] ||= []
          models[model]['belongs_to'][name.pluralize.underscore]['class_names'] << parent
          models[model]['belongs_to'][name.pluralize.underscore]['class_names'].uniq!
        else
          models[model]['belongs_to'][parent.underscore] ||= {}
          models[model]['belongs_to'][parent.underscore]['hidden'] = true if hidden
          models[model]['belongs_to'][parent.underscore]['polymorphic'] = true if polymorphic

          models[model]['belongs_to'][parent.underscore]['class_names'] ||= []
          models[model]['belongs_to'][parent.underscore]['class_names'] << parent
          models[model]['belongs_to'][parent.underscore]['class_names'].uniq!
        end
      end
      if multiplicity == "belongs_to"
        models[parent]['belongs_to'] ||= {}
        models[parent]['belongs_to'][name.underscore] ||= model && name != model ? { 'class_name' => model }: {}
        models[parent]['belongs_to'][name.underscore]['hidden'] = true if hidden
        models[parent]['belongs_to'][name.underscore]['polymorphic'] = true if polymorphic

        models[parent]['belongs_to'][name.underscore]['class_names'] ||= []
        models[parent]['belongs_to'][name.underscore]['class_names'] << model
        models[parent]['belongs_to'][name.underscore]['class_names'].uniq!

        models[model]['has_many'] ||= {}
        models[model]['has_many'][parent.pluralize.underscore] ||= (model && name != model) ? { 'class_name' => parent } : {}
        models[model]['has_many'][parent.pluralize.underscore]['dependent'] = dependent if dependent
        models[model]['has_many'][parent.pluralize.underscore]['polymorphic'] = true if polymorphic

        models[model]['has_many'][parent.pluralize.underscore]['class_names'] ||= []
        models[model]['has_many'][parent.pluralize.underscore]['class_names'] << model
        models[model]['has_many'][parent.pluralize.underscore]['class_names'].uniq!
      end
      if multiplicity == "has_one"
        if model && name != model
          models[parent]['belongs_to'] ||= {}
          models[parent]['belongs_to'][name.underscore] ||= model && name != model ? { 'class_name' => model }: {}
          models[parent]['belongs_to'][name.underscore]['dependent'] = dependent if dependent
          models[parent]['belongs_to'][name.underscore]['hidden'] = true if hidden
          models[parent]['belongs_to'][name.underscore]['polymorphic'] = true if polymorphic

          models[parent]['belongs_to'][name.underscore]['class_names'] ||= []
          models[parent]['belongs_to'][name.underscore]['class_names'] << model
          models[parent]['belongs_to'][name.underscore]['class_names'].uniq!

          models[model]['has_many'] ||= {}
          models[model]['has_many'][name.underscore + "_" + parent.underscore.pluralize] ||= model && name != model ? { 'class_name' => parent, 'foreign_key' => name + "_id" }: {}
          models[model]['has_many'][name.underscore + "_" + parent.underscore.pluralize]['dependent'] = dependent if dependent
          models[model]['has_many'][name.underscore + "_" + parent.underscore.pluralize]['polymorphic'] = true if polymorphic

          models[model]['has_many'][name.underscore + "_" + parent.underscore.pluralize]['class_names'] ||= []
          models[model]['has_many'][name.underscore + "_" + parent.underscore.pluralize]['class_names'] << parent
          models[model]['has_many'][name.underscore + "_" + parent.underscore.pluralize]['class_names'].uniq!
        else
          models[parent]['has_one'] ||= {}
          models[parent]['has_one'][name.underscore] = model && name != model ? { 'class_name' => model }: {}
          models[parent]['has_one'][name.underscore]['dependent'] = dependent if dependent
          models[parent]['has_one'][name.underscore]['hidden'] = true if hidden
          models[parent]['has_one'][name.underscore]['polymorphic'] = true if polymorphic

          models[parent]['has_one'][name.underscore]['class_names'] ||= []
          models[parent]['has_one'][name.underscore]['class_names'] << model
          models[parent]['has_one'][name.underscore]['class_names'].uniq!

          models[model]['belongs_to'] ||= {}
          models[model]['belongs_to'][parent.underscore] ||= model && name != model ? { 'class_name' => parent, 'foreign_key' => name + "_id" }: {}
          models[model]['belongs_to'][parent.underscore]['hidden'] = true if hidden
          models[model]['belongs_to'][parent.underscore]['polymorphic'] = true if polymorphic

          models[model]['belongs_to'][parent.underscore]['class_names'] ||= []
          models[model]['belongs_to'][parent.underscore]['class_names'] << parent
          models[model]['belongs_to'][parent.underscore]['class_names'].uniq!
        end

        #models[model]['belongs_to'] ||= {}
        #models[model]['belongs_to'][parent.underscore] ||= {}
        #models[model]['has_many'] ||= {}
        #models[model]['has_many'][parent.pluralize.underscore] ||= model && name != model ? { 'foreign_key' => name }: {}
      end
    end

  end




end
end
