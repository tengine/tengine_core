# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :"tengine/core/event" do
    event_type_name("event01")
    key { @uuid ||= UUID.new; @uuid.generate }
    source_name("server1")
    occurred_at { Time.now.utc }
    level(2) # info
    confirmed(false)
    sender_name("server1")
    properties({})
  end
end
