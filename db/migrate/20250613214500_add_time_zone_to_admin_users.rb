class AddTimeZoneToAdminUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :admin_users, :time_zone, :string
  end
end
