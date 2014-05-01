class OrderUsersController < WatchersController
  unloadable

  skip_before_filter :authorize
  before_filter :is_order_manager

  def is_order_manager
    render_403 unless User.current.admin? or Setting.plugin_redmine_app__space['auth_group']['order_mgmt'].empty? or
        User.current.is_or_belongs_to? Group.find(Setting.plugin_redmine_app__space['auth_group']['order_mgmt'].to_i)
  end

  def index
    begin
      @order = WorkOrder.find(params[:id])
      @issue = Issue.find_by_fixed_version_id(@order)
      @issue = @issue.first if @issue.is_a?(Array)
      @members = @issue.watchers.map{|w| Principal.find(w.user_id) }.sort
      @activities = TsActivity.where(:order_id => @order).map(&:activity_id)
      @permissions = TsPermission.over(@order).inject({}) do |h,v|
        h[v[:user_id]] = v[:access]
        h
      end

      (Setting.plugin_redmine_app__space['auth_group']['order_mgmt'].empty? ? User.all : User.where(:admin => true).all + User.in_group(Setting.plugin_redmine_app__space['auth_group']['order_mgmt'])).uniq.each do |user|
        @permissions[user.id] = TsPermission::ADMIN
      end
    rescue
      render_404
    end
  end

  def find_watchables
    klass = Object.const_get(params[:object_type].camelcase) rescue nil
    if klass && klass.respond_to?('watched_by')
      @watchables = klass.find_all_by_id(Array.wrap(params[:object_id]))
      #raise Unauthorized if @watchables.any? {|w| w.respond_to?(:visible?) && !w.visible?}
    end
    render_404 unless @watchables.present?
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
    perm = TsPermission.where(:user_id => params[:user_id]).where(:order_id => params[:id]).first
    if perm.nil?
      TsPermission.create(:user_id => params[:user_id], :order_id => params[:id], :access => params[:role])
    else
      perm.access = params[:role]
      perm.save!
    end
  end

end
