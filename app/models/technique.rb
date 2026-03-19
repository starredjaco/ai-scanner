class Technique < ApplicationRecord
    has_and_belongs_to_many :probes

    validates :name, presence: true, uniqueness: true
    validates :path, presence: true, uniqueness: true
    before_validation :normalize_path

    def self.ransackable_attributes(auth_object = nil)
        [ "id", "id_value", "name", "path" ]
    end

    private

    def normalize_path
        if path.blank?
            base_path = name.strip.downcase.gsub(/[^\w\s-]/, "").gsub(/\s+/, "_")

            # Check if this path already exists for a different name
            counter = 1
            candidate_path = base_path
            while Technique.where(path: candidate_path).where.not(name: name).exists?
                candidate_path = "#{base_path}_#{counter}"
                counter += 1
            end

            self.path = candidate_path
        end
    end
end
