# frozen_string_literal: true

# name: discourse-vk-auth
# about: Allows users to login to your forum using VK.com Authentication
# meta_topic_id: 12987
# version: 0.1
# author: Penar Musaraj
# url: https://github.com/discourse/discourse-vk-auth

enabled_site_setting :vk_auth_enabled
enabled_site_setting :vk_app_id
enabled_site_setting :vk_secure_key

gem "omniauth-vkontakte", "1.7.1"

class Auth::VkontakteAuthenticator < Auth::ManagedAuthenticator
  def name
    "vkontakte"
  end

  def enabled?
    SiteSetting.vk_auth_enabled
  end

  def register_middleware(omniauth)
    omniauth.provider :vkontakte,
                      setup:
                        lambda { |env|
                          strategy = env["omniauth.strategy"]
                          strategy.options[:client_id] = SiteSetting.vk_app_id
                          strategy.options[:client_secret] = SiteSetting.vk_secure_key
                          strategy.options[:scope] = "email"
                        }
  end

  def description_for_user(user)
    info = UserAssociatedAccount.find_by(provider_name: name, user_id: user.id)&.info
    return "" if info.nil?

    info["name"] || info["email"] || ""
  end

  def after_authenticate(auth_token, existing_account: nil)
    # Ignore extra data (we don't need it)
    auth_token[:extra] = {}
    super
  end

  # VK doesn't return unverified emails in their API so we're safe to assume
  # that emails we get from them are verified
  def primary_email_verified?(auth_token)
    true
  end
end

register_svg_icon "fab-vk" if respond_to?(:register_svg_icon)

auth_provider authenticator: Auth::VkontakteAuthenticator.new, icon: "fab-vk"
