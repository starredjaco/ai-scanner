FactoryBot.define do
  factory :metadatum do
    sequence(:key) { |n| "metadata_key_#{n}" }
    value { "metadata_value" }
  end
end
