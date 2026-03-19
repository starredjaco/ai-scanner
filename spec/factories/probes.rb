FactoryBot.define do
  factory :probe do
    sequence(:name) { |n| "Probe #{n}" }
    description { Faker::Lorem.paragraph }
    summary { Faker::Lorem.sentence }
    guid { SecureRandom.uuid }
    category { "security" }
    enabled { true }
    disclosure_status { "n-day" }
    social_impact_score { "Moderate Risk" }
    release_date { 1.year.ago }
    modified_date { 1.month.ago }
    published { false }
    published_at { nil }
    source { "garak" }

    trait :disabled do
      enabled { false }
    end

    trait :with_detector do
      association :detector
    end

    trait :with_techniques do
      after(:build) do |probe|
        probe.techniques << create_list(:technique, 2)
      end
    end

    trait :with_scans do
      after(:build) do |probe|
        probe.scans << create_list(:complete_scan, 2)
      end
    end

    trait :community do
      source { "garak" }
    end

    trait :published do
      published { true }
      published_at { 1.week.ago }
    end
  end
end
