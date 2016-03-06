class OauthsController < ApplicationController
  
  skip_before_filter :require_login

  # sends the user on a trip to the provider,
  # and after authorizing there back to the callback url.
  def oauth
    session[:oauth_last_url] = request.referer
    login_at(auth_params[:provider])
  end

  def callback
    provider = auth_params[:provider]
    redirect_url = session[:oauth_last_url] || home_path

    if @user = login_from(provider)
      redirect_to redirect_url, :notice => "Logged in with #{provider.titleize}!"
    else
      begin
        @user = create_from(auth_params[:provider])

        reset_session
        auto_login(@user)
        redirect_to redirect_url, :notice => "Signed up with #{provider.titleize}!"
      rescue
        redirect_to redirect_url, :alert => "Failed to login with #{provider.titleize}!"
      end
    end
  end

  private
  def auth_params
    params.permit(:code, :provider)
  end

end
