# frozen_string_literal: true

FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Company #{n}" }
    sequence(:slug) { |n| "company-#{n}" }
    tier { :tier_1 }

    trait :tier_1 do
      tier { :tier_1 }
    end

    trait :tier_2 do
      tier { :tier_2 }
    end

    trait :tier_3 do
      tier { :tier_3 }
    end

    trait :tier_4 do
      tier { :tier_4 }
    end

    # Legacy aliases for backwards compatibility in tests
    trait :free do
      tier { :tier_1 }
    end

    trait :small_business do
      tier { :tier_2 }
    end

    trait :business do
      tier { :tier_3 }
    end

    trait :enterprise do
      tier { :tier_4 }
    end

    trait :with_external_id do
      sequence(:external_id) { |n| "ext-#{n}" }
    end

    trait :with_scans_used do
      weekly_scan_count { 1 }
      week_start_date { Date.current.beginning_of_week }
    end

    trait :at_scan_limit do
      transient do
        tier_for_limit { :tier_1 }
      end

      tier { tier_for_limit }
      week_start_date { Date.current.beginning_of_week }

      after(:build) do |company, evaluator|
        limit = company.scans_per_week_limit
        company.weekly_scan_count = limit if limit
      end
    end

    trait :downgraded do
      downgrade_date { 30.days.ago.to_date }
    end
  end
end
