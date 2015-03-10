
class TsActivity < ActiveRecord::Base
  belongs_to :order, :class_name => 'WorkOrder', :foreign_key => 'order_id'
  has_many :activities, :class_name => 'TimeEntryActivity', :foreign_key => 'activity_id'

  attr_accessible :order_id, :activity_id, :activity_name
end