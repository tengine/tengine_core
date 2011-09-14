# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :"tengine/core/handler" do
    event_type_names(["abc", "123"])
    filepath("relative_path/from/dsl_dir/to/dsl.rb")
    lineno(10)
  end
end
