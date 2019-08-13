# frozen_string_literal: true

# name: discourse-crowd
# about: Atlassian Crowd Login Provider
# version: 0.1
# author: Robin Ward

require_dependency 'auth/oauth2_authenticator'

gem "omniauth_crowd", "2.2.3"

# mode of crowd authentication, how the discourse will behave after the user types in the
# credentials
class CrowdAuthenticatorMode

  def after_create_account(user, auth)
  end

end

# this is mode where when the user will create an account locally in the discourse,
# not using any provider, then the account won't be accessible by the crowd authentication method,
# that means you cannot log in by crowd in locally created account
class CrowdAuthenticatorModeSeparated < CrowdAuthenticatorMode

  def after_authenticate(auth)
    result = Auth::Result.new
    uid = auth[:uid]
    result.name = auth[:info].name
    result.username = uid
    result.email = auth[:info].email
    result.email_valid = true

    current_info = ::PluginStore.get("crowd", "crowd_user_#{uid}")
    if current_info
      result.user = User.where(id: current_info[:user_id]).first
    end

    # If no link exists try by email
    result.user ||= User.find_by_email(result.email)

    result.extra_data = { crowd_user_id: uid }
    result
  end

  def after_create_account(user, auth)
    ::PluginStore.set("crowd", "crowd_user_#{auth[:extra_data][:crowd_user_id]}", user_id: user.id)
  end

end

# mode of authentication, where user can access the locally created account with the
# crowd authentication method, is the opposity of `separated`
class CrowdAuthenticatorModeMixed < CrowdAuthenticatorMode

  def after_authenticate(auth)
    crowd_uid = auth[:uid]
    crowd_info = auth[:info]
    result = Auth::Result.new
    result.email_valid = true
    result.user = User.where(username: crowd_uid).first
    if (!result.user)
      result.user = User.new
      result.user.name = crowd_info.name
      result.user.username = crowd_uid
      result.user.email = crowd_info.email
      result.user.save
    end
    result
  end

end

class CrowdAuthenticator < ::Auth::OAuth2Authenticator
  def register_middleware(omniauth)
    OmniAuth::Strategies::Crowd.class_eval do
      def get_credentials
        if defined?(CSRFTokenVerifier) &&
            CSRFTokenVerifier.method_defined?(:form_authenticity_token)
          token = begin
            verifier = CSRFTokenVerifier.new
            verifier.call(env)
            verifier.form_authenticity_token
          end
        end

        OmniAuth::Form.build(title: (GlobalSetting.try(:crowd_popup_title) || GlobalSetting.try(:crowd_title) || "Crowd Authentication")) do
          text_field 'Login', 'username'
          password_field 'Password', 'password'
          html "\n<input type='hidden' name='authenticity_token' value='#{token}'/>" if token
          button 'Login'

          if GlobalSetting.respond_to?(:crowd_custom_html)
            html GlobalSetting.crowd_custom_html
          end
        end.to_response
      end
    end
    omniauth.provider :crowd,
                      name: 'crowd',
                      crowd_server_url: GlobalSetting.try(:crowd_server_url),
                      application_name: GlobalSetting.try(:crowd_application_name),
                      application_password: GlobalSetting.try(:crowd_application_password)
  end

  def initialize(provider)
    super(provider)
    if (defined? GlobalSetting.crowd_plugin_mode) && "mixed" == GlobalSetting.crowd_plugin_mode
      @mode = CrowdAuthenticatorModeMixed.new
    else
      @mode = CrowdAuthenticatorModeSeparated.new
    end
  end

  def after_authenticate(auth)
    if SiteSetting.crowd_verbose_log
      Rails.logger.warn("Crowd verbose log:\n #{auth.inspect}")
    end

    @mode.after_authenticate(auth)
  end

  def after_create_account(user, auth)
    @mode.after_create_account(user, auth)
  end

  def enabled?
    true
  end

end

title = GlobalSetting.try(:crowd_title) || "Crowd"
button_title = GlobalSetting.try(:crowd_title) || "with Crowd"

auth_provider title: button_title,
              authenticator: CrowdAuthenticator.new('crowd'),
              message: "Authorizing with #{title} (make sure pop up blockers are not enabled)",
              frame_width: 600,
              frame_height: 410
