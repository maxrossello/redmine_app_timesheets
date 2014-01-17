class OrderUsersController < WatchersController
  unloadable

  skip_before_filter :authorize

  def index
    @order = WorkOrder.find(params[:id]) rescue render_404
    @issue = Issue.find_by_fixed_version_id(@order)
    @issue = @issue.first if @issue.is_a?(Array)
    @members = @issue.watchers.map{|w| Principal.find(w.user_id) }.sort
    @activities = TsActivity.where(:order_id => @order).map(&:activity_id)
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
        TimeEntry.where(:fixed_version_id => params[:id].to_i).where("activity_id not in(?)", params[:activity].keys).update_all(:activity_id => params[:activity].keys.first)
      end

      redirect_to :controller => 'orders', :action => 'index'
    end
  end
end
