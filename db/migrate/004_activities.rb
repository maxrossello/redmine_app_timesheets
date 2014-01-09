class Activities < ActiveRecord::Migration
  def up
    create_table :ts_activities do |t|
      t.column :order_id, :integer, :null => false
      t.column :activity_id, :integer, :null => false
      t.column :activity_name, :string, :null => false
    end
    add_index :ts_activities, :order_id
  end

  def down
    drop_table :ts_activities
  end
end
