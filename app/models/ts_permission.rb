
class TsPermission < ActiveRecord::Base
  belongs_to :order, :class_name => 'WorkOrder', :foreign_key => 'order_id'
  belongs_to :principal

  attr_accessible :order_id, :principal_id, :access, :is_primary

  # permissions
  NONE = 0
  VIEW = 1
  EDIT = 2
  ADMIN = 3

  validates_inclusion_of :access, :in => NONE..ADMIN

  scope :for_user, lambda {|*args|
    user = (args.first || User.current)
    if Principal.find(user).is_a?(Group)
      user = Group.find(user).users.active
    end
    where(:principal_id => user)
  }

  scope :over, lambda {|order|
    where(:order_id => order)
  }

end