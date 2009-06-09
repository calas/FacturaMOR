require "config/environment"

DOC_DIR     = File.join(RAILS_ROOT, "doc")
MODEL_DIR   = File.join(RAILS_ROOT, "app/models")
FIXTURE_DIR = File.join(RAILS_ROOT, "test/fixtures")

TableInfo = Struct.new(:name, :attributes)
Attribute = Struct.new(:name, :type, :default, :isnull)
Association = Struct.new(:attr, :node1, :node2)

module VisualizeModels

  PREFIX = "Schema as of "

  # Use the column information in an ActiveRecord class
  # to create an 'Attribute' for each column.
  # The line contains the column name, the type
  # (and length), and any optional attributes
  def self.get_schema_info(klass)
    attrs = []
    klass.columns.each do |col|
      col_type = col.type.to_s
      col_type << "(#{col.limit})" if col.limit
    
      attrs << Attribute.new(col.name, col_type, col.default, !col.null)
    end

    return TableInfo.new(klass.name, attrs)
  end


  # Invoke neato or dot to create the image file
  def self.create_img(app, args, dot_file, img_file_base)
    img_file = img_file_base+".png"
    if system "#{app} #{args} -Tpng -o\"#{img_file}\" \"#{dot_file}\""
      puts "Generated #{img_file}"
    else
      puts "Failed to execute the '#{app}' command! Is grapviz (www.graphviz.org) installed? "
    end
  end

  # Create the .dot file that describes the graph
  def self.write_dot_file(header, target_dir, tableInfos)
    file_name = File.join(target_dir, "model_information.dot")
  
    f = File.open(file_name, "w")
    
    # Define a graph and some global settings
    f.write "digraph G {\n"
    f.write "\toverlap=false;\n"
	f.write "\tsplines=true;\n"
    f.write "\tnode [fontname=\"Helvetica\",fontsize=9];\n"
    f.write "\tedge [fontname=\"Helvetica\",fontsize=8];\n"
    f.write "\tranksep=0.1;\n"
    f.write "\tnodesep=0.1;\n"
#    f.write "\tedge [decorate=\"true\"];\n"

    # Write header info
    f.write "\t_schema_info [shape=\"plaintext\", label=\"#{header}\", fontname=\"Helvetica\",fontsize=8];\n"
    
    assocs = []
    # Draw the tables as boxes
    tableInfos.each do |table |
      attrs = ""
      table.attributes.each do | attr |
        if attr.name =~ /\_id$/
          # Create an association to other table
          table_name = Inflector.camelize(attr.name.sub(/\_id$/, ''))
          other_table = tableInfos.find { | other | other.name == table_name }
          assocs << Association.new(attr, table, other_table) if other_table != nil
        end
        attrs << "#{attr.name} : #{attr.type}"
        attrs << ", default: \\\"#{attr.default}\\\"" if attr.default
        attrs << "\\n"
      end
      f.write "\t\"#{table.name}\" [label=\"{#{table.name}|#{attrs}}\" shape=\"record\"];\n"
    end
    # Draw the relations
    assocs.each do | assoc |
      f.write "\t\"#{assoc.node1.name}\" -> \"#{assoc.node2.name}\" [label=\"#{assoc.attr.name}\"]\n"
    end
    
    # Close the graph
    f.write "}\n"
    f.close

    # Create the images by using dot and neato (grapviz tools)
    # We'll create several images with different layout. There is no "prefect" layout algorithm that suits all models
    #create_img("dot", "", file_name, File.join(target_dir, "model_overview_dot"))
    create_img("neato", "-Gmode=hier", file_name, File.join(target_dir, "model_overview_neato_hier"))
    create_img("neato", "", file_name, File.join(target_dir, "model_overview_neato_plain"))
    
    # Remove the .dot file
    File.delete file_name
  end

  # Return a list of the model files to annotate. If we have 
  # command line arguments, they're assumed to be either
  # the underscore or CamelCase versions of model names.
  # Otherwise we take all the model files in the 
  # app/models directory.
  def self.get_model_names
    models = ARGV.dup
    models.shift
    
    if models.empty?
      Dir.chdir(MODEL_DIR) do 
        models = Dir["*.rb"]
      end
    end
    models
  end

  # We're passed a name of things that might be 
  # ActiveRecord models. If we can find the class, and
  # if its a subclass of ActiveRecord::Base,
  # then pass it to the associated block
  def self.do_visualize
    header = PREFIX + Time.now.strftime("%d-%b-%Y %H:%M")
    version = ActiveRecord::Migrator.current_version rescue 0
    if version > 0
      header << "\\nSchema version #{version}"
    end
    
    tableInfos = []
    self.get_model_names.each do |m|
      class_name = Inflector.camelize(m.sub(/\.rb$/, ''))
      klass = Object.const_get(class_name) rescue nil
      if klass && klass < ActiveRecord::Base
        puts "Looking at #{class_name}"
        tableInfos << get_schema_info(klass) rescue puts "... failed!"
      else
        puts "Skipping #{class_name}"
      end
    end
    
    if !File.directory?(DOC_DIR)
      puts "Creating directory \"#{DOC_DIR}\"..."
      Dir.mkdir DOC_DIR
    end    
    write_dot_file(header, DOC_DIR, tableInfos)
  end
end
