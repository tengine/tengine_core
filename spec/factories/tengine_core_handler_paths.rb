# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :"tengine/core/handler_path" do
    event_type_name("MyString")
    driver(nil)
    handler_id("")
  end
end
