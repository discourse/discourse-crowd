# name: discourse-crowd
# about: Atlassian Crowd Login Provider
# version: 0.1
# author: Robin Ward

require_dependency 'auth/oauth2_authenticator'

gem "omniauth_crowd", "2.2.2"

class CrowdAuthenticatorMode

  attr_accessor :after_authenticate, :after_create_account

  # this is mode where when the user will create an account locally in the discourse,
  # not using any provider, then the account won't be accessible by the crowd authentication method,
  # that means you cannot log in by crowd in locally created account
  def self.separated
    mode = CrowdAuthenticatorMode.new

    mode.after_authenticate = lambda do |auth|
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
      result.extra_data = { crowd_user_id: uid }
      result
    end

    mode.after_create_account = lambda do |user, auth|
      ::PluginStore.set("crowd", "crowd_user_#{auth[:extra_data][:crowd_user_id]}", {user_id: user.id })
    end

    mode

  end

end

class CrowdAuthenticator < ::Auth::OAuth2Authenticator
  def register_middleware(omniauth)
    OmniAuth::Strategies::Crowd.class_eval do
      def get_credentials
        OmniAuth::Form.build(:title => (options[:title] || "Crowd Authentication")) do
          text_field 'Login', 'username'
          password_field 'Password', 'password'

          if GlobalSetting.respond_to?(:crowd_custom_html)
            html GlobalSetting.crowd_custom_html
          end
        end.to_response
      end
    end
    omniauth.provider :crowd,
                      :name => 'crowd',
                      :crowd_server_url => GlobalSetting.crowd_server_url,
                      :application_name => GlobalSetting.crowd_application_name,
                      :application_password => GlobalSetting.crowd_application_password
  end

  def initialize(provider)
    super(provider)
      @mode = CrowdAuthenticatorMode.separated
    end
  end

  def after_authenticate(auth)
    @mode.after_authenticate.call(auth)
  end

  def after_create_account(user, auth)
    @mode.after_create_account.call(user, auth)
  end

end

title = GlobalSetting.try(:crowd_title) || "Crowd"
button_title = GlobalSetting.try(:crowd_title) || "with Crowd"

auth_provider :title => button_title,
              :authenticator => CrowdAuthenticator.new('crowd'),
              :message => "Authorizing with #{title} (make sure pop up blockers are not enabled)",
              :frame_width => 600,
              :frame_height => 380,
              :background_color => '#003366'
