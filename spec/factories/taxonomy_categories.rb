FactoryBot.define do
  factory :taxonomy_category do
    sequence(:name) { |n| "Category #{n}" }
  end
end
