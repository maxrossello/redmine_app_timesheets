class OrderUsersController < WatchersController
  unloadable

  skip_before_filter :authorize

  def index
    @order = Version.find(params[:id]) rescue render_404
    @issue = Issue.find_by_fixed_version_id(@order)
    @issue = @issue.first if @issue.is_a?(Array)
    @members = @issue.watchers.map{|w| Principal.find(w.user_id) }.sort
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
    render_404 unless params[:id]

    value = Setting.plugin_redmine_app_timesheets

    value['activities'] = {} if value['activities'].nil?
    # convert hash to array and revert couples
    value['activities'][params[:id]] = params['activity'].map {|x| x.to_a}[0].each do |x| x.reverse! end

    Setting['plugin_redmine_app_timesheets'] = value

    redirect_to :controller => 'orders', :action => 'index'
  end
end
