class AddStatusToTargets < ActiveRecord::Migration[8.0]
  def change
    add_column :targets, :status, :integer, default: 0, null: false
    add_column :targets, :validation_text, :text
    add_index :targets, :status

    delay = 10.seconds
    Target.where(status: 0).find_each do |target|
      ValidateTargetJob.set(wait: delay).perform_later(target.id)
      delay += 15.seconds
    end
  end
end
