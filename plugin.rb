# name: discourse-crowd
# about: Atlassian Crowd Login Provider
# version: 0.1
# author: Robin Ward

require_dependency 'auth/oauth2_authenticator'

gem "omniauth_crowd", "2.2.2"

class CrowdAuthenticator < ::Auth::OAuth2Authenticator
  def register_middleware(omniauth)
    omniauth.provider :crowd,
                      :name => 'crowd',
                      :crowd_server_url => GlobalSetting.crowd_server_url,
                      :application_name => GlobalSetting.crowd_application_name,
                      :application_password => GlobalSetting.crowd_application_password
  end

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
    result.extra_data = { crowd_user_id: uid }
    result
  end

  def after_create_account(user, auth)
    ::PluginStore.set("crowd", "crowd_user_#{auth[:extra_data][:crowd_user_id]}", {user_id: user.id })
  end

end

title = GlobalSetting.try(:crowd_title) || "Crowd"
button_title = GlobalSetting.try(:crowd_title) || "with Crowd"

auth_provider :title => button_title,
              :authenticator => CrowdAuthenticator.new('crowd'),
              :message => "Authorizing with #{title} (make sure pop up blockers are not enabled)",
              :frame_width => 600,
              :frame_height => 350,
              :background_color => '#003366'
