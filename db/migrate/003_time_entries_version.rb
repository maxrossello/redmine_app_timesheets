class TimeEntriesVersion < ActiveRecord::Migration

  def self.up
    add_column :time_entries, :fixed_version_id, :integer
  end

  def self.down
    remove_column :time_entries, :fixed_version_id
  end

end