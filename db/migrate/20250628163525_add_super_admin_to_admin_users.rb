class AddSuperAdminToAdminUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :admin_users, :super_admin, :boolean, default: false, null: false
    add_index :admin_users, :super_admin
  end
end
