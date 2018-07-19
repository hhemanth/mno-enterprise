module MnoEnterprise::Concerns::Controllers::Jpi::V1::Admin::BaseResourceController
  extend ActiveSupport::Concern

  #==================================================================
  # Included methods
  #==================================================================
  # 'included do' causes the included code to be evaluated in the
  # context where it is included rather than being executed in the module's context
  included do
    ADMIN_CACHE_DURATION = 12.hours
    before_filter :check_authorization
    before_filter :block_support_users
  end

  protected

  # This method is created to properly scope api calls to MnoHub with account_manager users.
  def special_roles_metadata
    { act_as_manager: current_user.id }
  end

  def timestamp
    @timestamp ||= (params[:timestamp] || 0).to_i
  end

  # Check current user is logged in
  # Check organization is valid if specified
  def check_authorization
    return true if current_user && current_user.admin_role.present?
    status = current_user ? :forbidden : :unauthorized
    render nothing: true, status: status
    false
  end

  # Blacklist support users from all admin routes. To whitelist a route for a
  # support_user, skip the callback, and create a proper callback, or CanCan
  # authorization inside the controller action.
  def block_support_users
    return true unless current_user.support?
    status = current_user ? :forbidden : :unauthorized
    render nothing: true, status: status
    false
  end

  # Generic authorization that can be called as a #before_filter in a controller with organization params.
  def authorize_support_user_organization
    return true unless current_user.support?
    authorize! :read, MnoEnterprise::Organization.new(id: support_org_params)
  end

  # Generic organization parameters, can be monkeypatched in controller with appropriate organization id.
  # e.g. in organization controller it can be monkey patched to #params[:id]
  def support_org_params
    params[:organization_id]
  end

  def render_not_found(resource = controller_name.singularize, id = params[:id])
    render json: { errors: {message: "#{resource.titleize} not found (id=#{id})", code: 404, params: params} }, status: :not_found
  end

  def render_bad_request(attempted_action, issue)
    render json: { errors: {message: "Error while trying to #{attempted_action}: #{issue}", code: 400, params: params} }, status: :bad_request
  end

  def render_forbidden_request(attempted_action)
    render json: { errors: {message: "Error while trying to #{attempted_action}: you do not have permission", code: 403} }, status: :forbidden
  end
end
