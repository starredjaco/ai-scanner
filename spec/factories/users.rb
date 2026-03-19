# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    transient do
      company { nil }  # Allow passing company directly
      company_tier { :tier_1 }
    end

    sequence(:email) { |n| "admin#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    super_admin { false }
    time_zone { "UTC" }

    after(:create) do |user, evaluator|
      # If company was explicitly passed, use it; otherwise create one by default
      target_company = evaluator.company || create(:company, tier: evaluator.company_tier)
      create(:membership, user: user, company: target_company)
      user.update!(current_company: target_company)
    end

    trait :super_admin do
      super_admin { true }
    end

    trait :regular_admin do
      super_admin { false }
    end

    trait :without_company do
      after(:create) { |user, evaluator| } # Override to do nothing
    end

    # Tier traits
    trait :tier_1 do
      company_tier { :tier_1 }
    end

    trait :tier_2 do
      company_tier { :tier_2 }
    end

    trait :tier_3 do
      company_tier { :tier_3 }
    end

    trait :tier_4 do
      company_tier { :tier_4 }
    end

    # Legacy aliases for backwards compatibility
    trait :free_tier do
      company_tier { :tier_1 }
    end

    trait :small_business_tier do
      company_tier { :tier_2 }
    end

    trait :business_tier do
      company_tier { :tier_3 }
    end

    trait :enterprise_tier do
      company_tier { :tier_4 }
    end
  end
end
