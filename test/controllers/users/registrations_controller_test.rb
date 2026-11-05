# frozen_string_literal: true

require "test_helper"

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    ActionMailer::Base.deliveries.clear
    cookies[:locale] = "fr"
  end

  test "sign up sends a confirmation email and stays signed out until the address is confirmed" do
    assert_enqueued_emails 1 do
      post user_registration_path, params: {
        user: {
          name: "Ada",
          email: "ada@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_match I18n.t("devise.registrations.signed_up_but_unconfirmed", locale: :fr), response.body

    user = User.find_by!(email: "ada@example.com")
    assert_not user.confirmed?

    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "ada@example.com" ], mail.to
    assert_equal "Confirmez votre e-mail Forge", mail.subject
    assert_includes mail.html_part.body.to_s, "© #{Time.current.year} #1344 Solutions"
    assert mail.attachments["forge-mark.png"].inline?

    token = CGI.unescapeHTML(mail.html_part.body.to_s)[/confirmation_token=([^"&\s]+)/, 1]
    get user_confirmation_path(confirmation_token: CGI.unescape(token))
    assert_redirected_to new_user_session_path
    assert user.reload.confirmed?

    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    assert_redirected_to new_website_path
  end

  test "an unconfirmed account cannot sign in" do
    user = User.create!(name: "Ada", email: "ada-pending@example.com", password: "password123")

    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_match I18n.t("devise.failure.unconfirmed", locale: :fr), response.body
  end
end
