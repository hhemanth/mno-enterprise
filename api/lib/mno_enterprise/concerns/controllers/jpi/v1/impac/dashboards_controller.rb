module MnoEnterprise::Concerns::Controllers::Jpi::V1::Impac::DashboardsController
  extend ActiveSupport::Concern

  #==================================================================
  # Included methods
  #==================================================================
  # 'included do' causes the included code to be evaluated in the
  # context where it is included rather than being executed in the module's context
  included do
    respond_to :json
  end

  DASHBOARD_DEPENDENCIES = [:widgets, {widgets: :kpis}, :kpis, {kpis: :alerts}]

  #==================================================================
  # Instance methods
  #==================================================================
  # GET /mnoe/jpi/v1/impac/dashboards
  def index
    dashboards
  end

  # GET /mnoe/jpi/v1/impac/dashboards/1
  #   -> GET /api/mnoe/v1/users/1/dashboards
  def show
    render_not_found('dashboard') unless dashboard(*DASHBOARD_DEPENDENCIES)
  end

  # POST /mnoe/jpi/v1/impac/dashboards
  #   -> POST /api/mnoe/v1/users/1/dashboards
  def create
    # TODO: dashboards.build breaks as dashboard.organization_ids returns nil, instead of an
    #       empty array. (see MnoEnterprise::Impac::Dashboard #organizations)
    # @dashboard = dashboards.build(dashboard_create_params)
    # TODO: enable authorization
    # authorize! :manage_dashboard, @dashboard
    # if @dashboard.save
    @dashboard = MnoEnterprise::Dashboard.create(dashboard_create_params)
    if @dashboard.errors.empty?
      MnoEnterprise::EventLogger.info('dashboard_create', current_user.id, 'Dashboard Creation', @dashboard)
      @dashboard = dashboard.load_required(*DASHBOARD_DEPENDENCIES)
      render 'show'
    else
      render_bad_request('create dashboard', @dashboard.errors)
    end
  end

  # PUT /mnoe/jpi/v1/impac/dashboards/1
  #   -> PUT /api/mnoe/v1/dashboards/1
  def update
    return render_not_found('dashboard') unless dashboard

    # TODO: enable authorization
    # authorize! :manage_dashboard, dashboard
    dashboard.update_attributes(dashboard_update_params)
    if dashboard.errors.empty?
      # Reload Dashboard
      @dashboard = dashboard.load_required(DASHBOARD_DEPENDENCIES)
      render 'show'
    else
      render_bad_request('update dashboard', dashboard.errors)
    end
  end

  # DELETE /mnoe/jpi/v1/impac/dashboards/1
  #   -> DELETE /api/mnoe/v1/dashboards/1
  def destroy
    return render_not_found('dashboard') unless dashboard
    MnoEnterprise::EventLogger.info('dashboard_delete', current_user.id, 'Dashboard Deletion', dashboard)
    # TODO: enable authorization
    # authorize! :manage_dashboard, dashboard
    dashboard.destroy
    head status: :ok
  end

  private

    def dashboard(*included)
      @dashboard ||= MnoEnterprise::Dashboard.find_one(params[:id].to_i, included)
    end

    def dashboards
      @dashboards ||= MnoEnterprise::Dashboard.includes(:widgets, *DASHBOARD_DEPENDENCIES).find(owner_id: current_user.id)
    end

    def whitelisted_params
      [:name, :currency, {widgets_order: []}, {organization_ids: []}]
    end

    # Allows all metadata attrs to be permitted, and maps it to :settings
    # for the Her "meta_data" issue.
    def dashboard_params
      params.require(:dashboard).permit(*whitelisted_params).tap do |whitelisted|
        whitelisted[:settings] = params[:dashboard][:metadata] || {}
      end
      .except(:metadata)
      .merge(owner_type: "User", owner_id: current_user.id)
    end
    alias :dashboard_update_params  :dashboard_params
    alias :dashboard_create_params  :dashboard_params

end
