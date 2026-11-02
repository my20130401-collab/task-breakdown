FactoryBot.define do
  factory :decomposition do
    task { nil }
    status { 1 }
    granularity { 1 }
    model { "MyString" }
    request_payload { "" }
    response_payload { "" }
    error_message { "MyText" }
  end
end
