class OrderUsersController < ApplicationController
  unloadable

  before_filter :is_order_manager

  def is_order_manager
    render_403 unless User.current.admin? or Setting.plugin_redmine_app__space['auth_group']['order_mgmt'].empty? or
        User.current.is_or_belongs_to? Group.find(Setting.plugin_redmine_app__space['auth_group']['order_mgmt'].to_i)
  end

  def index
    begin
      @order = WorkOrder.find(params[:id])
      @members = TsPermission.where(:is_primary => true, :order_id => @order.id).order('access DESC').map{|p| p.principal}.sort{|a,b| a.is_a?(User) ? (b.is_a?(User) ? 0 : -1) : (b.is_a?(Group) ? 0 : 1) }
      @activities = TsActivity.where(:order_id => @order).map(&:activity_id)
      @permissions = TsPermission.over(@order).inject({}) do |h,v|
        h[v[:principal_id]] = v[:access]
        h
      end

      (Setting.plugin_redmine_app__space['auth_group']['order_mgmt'].empty? ? User.all : User.where(:admin => true).all + User.in_group(Setting.plugin_redmine_app__space['auth_group']['order_mgmt'])).uniq.each do |user|
        @permissions[user.id] = TsPermission::ADMIN
      end
    rescue
      render_404
    end
  end

  def create
    order = WorkOrder.find(params[:id])
    user_ids = []
    user_ids << params[:order_users][:user_ids]
    user_ids.flatten.compact.uniq.each do |user_id|
      p = TsPermission.where(:order_id => order.id, :principal_id => user_id).first
      if p.nil?
        p = TsPermission.new(:order_id => order.id, :principal_id => user_id, :access => TsPermission::NONE)
      end
      p.is_primary = true
      p.save!
    end
    redirect_to_referer_or {render :text => (Principal.find(user_ids[0]).is_a?(User) ? 'User added.' : 'Group added.'), :layout => true}
  end

  def destroy
    user = Principal.find(params[:user_id])
    p = TsPermission.where(:order_id => params[:order_id], :principal_id => user.id).first
    if user.is_a?(User)
      p.is_primary = false
      p.save!
    else
      p.destroy
    end unless p.nil?
    redirect_to :back
  end

  def activities
    if params[:id].nil? or params['activity'].nil?
      flash.alert = "Cannot save an empty activity list"
      render_403
    else
      TsActivity.destroy_all(:order_id => params[:id].to_i)
      TsActivity.transaction do
        params[:activity].each do |id, name|
          TsActivity.create(:order_id => params[:id].to_i, :activity_id => id, :activity_name => name)
        end
      end

      # be sure there is no time entry with invalid activity
      if WorkOrder.find(params[:id].to_i).project_id == Setting.plugin_redmine_app_timesheets['project'].to_i
        TimeEntry.where(:order_id => params[:id].to_i).where("order_activity_id not in(?)", params[:activity].keys).update_all(:order_activity_id => params[:activity].keys.first)
      end

      redirect_to :controller => 'orders', :action => 'index'
    end
  end

  def set_permission
    perm = TsPermission.where(:principal_id => params[:user_id]).where(:order_id => params[:id]).first
    if perm.nil?
      TsPermission.create(:principal_id => params[:user_id], :order_id => params[:id], :access => params[:role])
    else
      perm.access = params[:role]
      perm.save!
    end
  end

  def autocomplete_for_user
    @users = User.active.sorted.like(params[:q]).limit(100)
    @users -= TsPermission.where(:order_id => params[:id], :is_primary => true).map{|p| p.principal if p.principal.is_a?(User)}
    render :layout => false
  end

  def autocomplete_for_group
    @users = Group.active.sorted.like(params[:q]).limit(100)
    @users -= TsPermission.where(:order_id => params[:id], :is_primary => true).map{|p| p.principal if p.principal.is_a?(Group)}
    render :layout => false
  end
end
