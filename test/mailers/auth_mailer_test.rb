# frozen_string_literal: true

require "test_helper"

class AuthMailerTest < ActionMailer::TestCase
  setup do
    @user = User.new(name: "Ada", email: "ada@example.com")
  end

  test "every authentication email shares the Forge shell in both locales" do
    I18n.available_locales.each do |locale|
      emails_for(locale).each do |mail|
        assert_forge_shell mail, locale: locale
      end
    end
  end

  test "confirmation and reset emails carry their link" do
    confirmation = AuthMailer.confirmation_instructions(@user, "confirm-token", locale: "en")
    reset = AuthMailer.reset_password_instructions(@user, "reset-token", locale: "en")
    assert_includes confirmation.html_part.body.to_s, "confirmation_token=confirm-token"
    assert_includes confirmation.text_part.body.to_s, "confirmation_token=confirm-token"
    assert_includes reset.html_part.body.to_s, "reset_password_token=reset-token"
    assert_includes reset.text_part.body.to_s, "reset_password_token=reset-token"
    assert_equal "Confirm your Forge email", confirmation.subject
    assert_equal "Reset your Forge password", reset.subject
  end

  test "a pending email change uses the reconfirmation copy" do
    @user.unconfirmed_email = "new@example.com"
    mail = AuthMailer.confirmation_instructions(@user, "confirm-token", locale: "fr", to: "new@example.com")

    assert_equal "Confirmez votre e-mail Forge", mail.subject
    assert_includes mail.html_part.body.to_s, "new@example.com"
    assert_includes mail.text_part.body.to_s, I18n.t("user.mailer.reconfirm_eyebrow", locale: :fr)

    notice = AuthMailer.email_changed(@user, locale: "fr", to: "ada@example.com")
    assert_includes notice.text_part.body.to_s, I18n.t("user.mailer.email_changing_body", email: "new@example.com", locale: :fr)
    assert_includes notice.html_part.body.to_s, "new@example.com"
  end

  private

  def emails_for(locale)
    opts = { locale: locale }
    [
      AuthMailer.confirmation_instructions(@user, "confirm-token", opts.dup),
      AuthMailer.reset_password_instructions(@user, "reset-token", opts.dup),
      AuthMailer.email_changed(@user, opts.dup.merge(to: @user.email)),
      AuthMailer.password_change(@user, opts.dup)
    ]
  end

  def assert_forge_shell(mail, locale:)
    html = mail.html_part.body.to_s
    text = mail.text_part.body.to_s
    copyright = I18n.t("user.mailer.copyright", year: Time.current.year, locale: locale)
    footer = I18n.t("user.mailer.footer", locale: locale)

    assert_match(/La Forge/, mail[:from].decoded)
    assert_equal [ "noreply@1344.fr" ], mail.from
    assert mail.attachments["forge-mark.png"].inline?
    [ html, text ].each do |body|
      assert_includes body, copyright
      assert_includes body, footer
      assert_includes body, "Ada"
    end
    assert_includes html, attachments_cid(mail)
  end

  def attachments_cid(mail)
    mail.attachments["forge-mark.png"].url
  end
end
