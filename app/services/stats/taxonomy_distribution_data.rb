module Stats
  class TaxonomyDistributionData
    def initialize(options = {})
    end

    def call
      taxonomy_counts = TaxonomyCategory
        .select("taxonomy_categories.id, taxonomy_categories.name, COUNT(DISTINCT probes.id) as probe_count")
        .left_joins(:probes)
        .group("taxonomy_categories.id, taxonomy_categories.name")
        .order("taxonomy_categories.name")

      data = taxonomy_counts.map do |result|
        {
          name: result.name,
          value: result.probe_count
        }
      end

      {
        categories: data.map { |item| item[:name] },
        data: data
      }
    end
  end
end
