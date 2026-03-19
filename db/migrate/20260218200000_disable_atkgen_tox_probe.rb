class DisableAtkgenToxProbe < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE probes SET enabled = false WHERE name = 'atkgen.Tox' AND category = 'garak' AND source = 'garak'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE probes SET enabled = true WHERE name = 'atkgen.Tox' AND category = 'garak' AND source = 'garak'
    SQL
  end
end
