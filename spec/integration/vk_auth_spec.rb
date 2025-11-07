# frozen_string_literal: true

describe "VK Oauth2" do
  let(:access_token) { "vk_access_token_448" }
  let(:app_id) { "abcdef11223344" }
  let(:secure_key) { "adddcccdddd99922" }
  let(:temp_code) { "vk_temp_code_544254" }
  let(:vk_user_id) { 9_829_345_845_345 }

  fab!(:user)

  def setup_vk_email_stub(email:)
    stub_request(:post, "https://oauth.vk.ru/access_token").with(
      body:
        hash_including("client_id" => app_id, "client_secret" => secure_key, "code" => temp_code),
    ).to_return(
      status: 200,
      body: Rack::Utils.build_query(access_token: access_token, email: email, user_id: vk_user_id),
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
      },
    )
  end

  before do
    SiteSetting.vk_auth_enabled = true
    SiteSetting.vk_app_id = app_id
    SiteSetting.vk_secure_key = secure_key

    stub_request(
      :get,
      "https://api.vk.ru/method/users.get?access_token=#{access_token}&fields=nickname,screen_name,sex,city,country,online,bdate,photo_50,photo_100,photo_200,photo_200_orig,photo_400_orig&https=0&lang=&v=5.107",
    ).to_return(
      status: 200,
      body: JSON.dump(response: [{ id: vk_user_id.to_s, first_name: "Russian", last_name: "Guy" }]),
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  it "signs in the user if the API response from VK includes an email (implies it's verified) and the email matches an existing user's" do
    post "/auth/vkontakte"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://oauth.vk.ru/authorize")

    setup_vk_email_stub(email: user.email)

    post "/auth/vkontakte/callback", params: { state: session["omniauth.state"], code: temp_code }
    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to eq(user.id)
  end

  it "doesn't sign in anyone if the API response from VK doesn't include an email (implying the user's email on VK isn't verified)" do
    post "/auth/vkontakte"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://oauth.vk.ru/authorize")

    setup_vk_email_stub(email: nil)

    post "/auth/vkontakte/callback", params: { state: session["omniauth.state"], code: temp_code }
    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to be_blank
  end
end
