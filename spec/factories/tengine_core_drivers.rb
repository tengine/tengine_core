# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :"tengine/core/driver" do
    name("MyString")
    version("MyString")
    enabled(false)
    enabled_on_activation(false)
  end
end
