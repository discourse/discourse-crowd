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

  def set_groups(user, auth)
    return unless SiteSetting.crowd_groups_enabled
    Rails.logger.debug("DEBUG: auth: '#{auth.inspect}'")
    user_crowd_groups = ( auth[:info] && auth[:info].groups ) ? auth[:info].groups : nil
    group_map = Hash.new
    check_groups = Hash.new
    SiteSetting.crowd_groups_mapping.split("|").each { |map|
      keyval = map.split(":", 2)
      group_map[keyval[0]] = keyval[1]
      check_groups[keyval[1]] = 0
    }
    if !(user_crowd_groups == nil || group_map.empty?)
      user_crowd_groups.each { |user_crowd_group|
        if group_map.has_key?(user_crowd_group) || !SiteSetting.crowd_groups_remove_unmapped_groups
          result = nil
          discourse_groups = group_map[user_crowd_group] || ""
          discourse_groups.split(",").each { |discourse_group|
            next unless discourse_group
            check_groups[discourse_group] = 1
            actual_group = Group.find_by(name: discourse_group)
            next if actual_group.automatic # skip if it's an auto_group
            if (!actual_group)
              Rails.logger.warn("WARN: crowd_group '#{user_crowd_group}' is configured to map to discourse_group '#{discourse_group}' but this does not seem to exist")
              next
            end
            result = actual_group.add(user)
            Rails.logger.debug("DEBUG: user_crowd_group '#{user_crowd_group}' mapped to discourse_group '#{discourse_group}' added to user '#{user.username}'") if result && SiteSetting.crowd_verbose_log
          }
        end
      }
    end
    check_groups.keys.each { |discourse_group|
      actual_group = Group.find_by(name: discourse_group)
      next unless actual_group
      next if actual_group.automatic # skip if it's an auto_group
      next if check_groups[discourse_group] > 0
      result = actual_group.remove(user)
      Rails.logger.warn("DEBUG: User '#{user.username}' removed from discourse_group '#{discourse_group}'") if result && SiteSetting.crowd_verbose_log
    }
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
# Allow setting to decide whether to validate email or not. Some Jira setups don't.
    result.email_valid = SiteSetting.crowd_validate_email

    current_info = ::PluginStore.get("crowd", "crowd_user_#{uid}")
    if current_info
      result.user = User.where(id: current_info[:user_id]).first
    end

    # If no link exists try by email
    result.user ||= User.find_by_email(result.email)

    set_groups(result.user, auth) if result.user

    result.extra_data = { crowd_user_id: uid }
    result
  end

  def after_create_account(user, auth)
    ::PluginStore.set("crowd", "crowd_user_#{auth[:extra_data][:crowd_user_id]}", user_id: user.id)
    set_groups(user, auth)
  end

  def set_groups(user, auth)
    super(user, auth)
  end
end

# mode of authentication, where user can access the locally created account with the
# crowd authentication method, is the opposity of `separated`
class CrowdAuthenticatorModeMixed < CrowdAuthenticatorMode

  def after_authenticate(auth)
    crowd_uid = auth[:uid]
    crowd_info = auth[:info]
    result = Auth::Result.new
# Allow setting to decide whether to validate email or not. Some Jira setups don't.
    result.email_valid = SiteSetting.crowd_validate_email
    result.user = User.where(username: crowd_uid).first
    if (!result.user)
      result.user = User.new
      result.user.name = crowd_info.name
      result.user.username = crowd_uid
      result.user.email = crowd_info.email
      result.user.save
    end
    set_groups(user, auth)
    result
  end

  def after_create_account(user, auth)
    set_groups(user, auth)
  end

  def set_groups(user, auth)
    super(user, auth)
  end
end

class CrowdAuthenticator < ::Auth::OAuth2Authenticator
  def register_middleware(omniauth)
    return unless GlobalSetting.try(:crowd_server_url).present?

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

        
        if (defined? GlobalSetting.crowd_custom_css)
          if (defined? GlobalSetting.crowd_css_replace) && "true" == GlobalSetting.crowd_css_replace
            OmniAuth.config.form_css = GlobalSetting.crowd_custom_css
          else
            OmniAuth.config.form_css << GlobalSetting.crowd_custom_css
          end
        end
        OmniAuth::Form.build(title: (GlobalSetting.try(:crowd_popup_title) || GlobalSetting.try(:crowd_title) || "Crowd Authentication")) do
          text_field 'Username', 'username'
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

auth_provider title: GlobalSetting.try(:crowd_title),
              authenticator: CrowdAuthenticator.new('crowd')
