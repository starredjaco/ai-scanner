# frozen_string_literal: true

FactoryBot.define do
  factory :membership do
    user { nil }
    company { nil }

    # Allow creating with both at once
    trait :with_user_and_company do
      user
      company
    end
  end
end
