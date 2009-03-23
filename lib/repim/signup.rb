module Repim
  module Signup
    def self.included(base)
      base.before_filter :authenticate, :except => [:create]
    end

    def create
      @account = Account.new(params[:account])
      @account.identity_url = session[:identity_url]

      respond_to do |format|
        if @account.save
          flash[:notice] = 'Account was successfully created.'
          reset_session
          self.current_user = @account
          format.html { redirect_to(after_create_url) }
        else
          format.html { render :action => "new" }
        end
      end
    end

    private
    def after_create_url
      current_user
    end
  end
end
