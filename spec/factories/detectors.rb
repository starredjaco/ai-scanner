FactoryBot.define do
  factory :detector do
    sequence(:name) { |n| "#{Faker::App.name}-#{n}" }

    trait :with_probes do
      after(:build) do |detector|
        create_list(:probe, 2, detector: detector)
      end
    end
  end
end
