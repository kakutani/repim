require 'repim/ax_attributes_adapter'

module Repim
  module RelyingParty
    def self.included(base)
      base.cattr_accessor :attribute_adapter
      base.cattr_accessor :signup_template

      base.skip_before_filter :authenticate
      base.signup_template = "users/new" # will be nice if configurable

      base.extend(ClassMethods)
    end

    module ClassMethods
      def use_attribute_exchange(prefixes, propaties)
        self.attribute_adapter = AxAttributeAdapter.new(prefixes, propaties)
      end
    end

    # render new.rhtml
    def new
    end

    def create
      options = {}
      options[attribute_adapter.necessity] = attribute_adapter.keys if attribute_adapter

      begin
        authenticate_with_open_id(params[:openid_url], options) do |result, identity_url, personal_data|
          if result.successful?
            authenticate_success(identity_url, personal_data)
          else
            authenticate_failure(params.merge(:openid_url=>identity_url))
          end
        end
      rescue OpenID::OpenIDError => why
        logger.debug{ [why.message, why.backtrace].flatten.join("\n\t") }
        authenticate_failure(params)
      end
    end

    def destroy
      session[:user_id] = nil
      reset_session
      flash[:notice] = "You have been signed out."

      redirect_back_or(after_logout_path)
    end

    private
    def authenticate_success(identity_url, personal_data = {})
      if user = Account.find_by_identity_url(identity_url)
#      if user = user_klass.find_by_identity_url(identity_url)
        login_successfully(user, personal_data)
        redirect_back_or(after_login_path)
      else
        signup(identity_url, personal_data)
        render(:template => signup_template)
      end
    end

    def login_successfully(user, personal_data)
      reset_session
      self.current_user = user
      flash[:notice] ||= "Logged in successfully"
    end

    def signup(identity_url, ax = {})
      session[:identity_url] = identity_url
      # got to override when I need change instance create strategy.
      @account = user_klass.new( attribute_adapter ? attribute_adapter.adapt(ax) : {} )
    end

    # log sign in faulure. and re-render sessions/new
    def authenticate_failure(assigns = params)
      flash[:error] = "Couldn't sign you in as '#{assigns[:openid_url] || assigns["openid.claimed_id"]}'"
      logger.warn "Failed signin for '#{assigns[:openid_url]}' from #{request.remote_ip} at #{Time.now.utc}"

      @openid_url  = assigns[:openid_url]

      render :action => 'new'
    end

    def after_login_path; root_path ; end
    def after_logout_path; signin_path ; end

    def method_missing(m, *args, &b)
      return [request.protocol, request.host_with_port, "/"].join if m.to_sym == :root_url
      super
    end

    def verify_authenticity_token
       super unless ('create' == params[:action] && '1' == params[:open_id_complete])
    end
  end
end
